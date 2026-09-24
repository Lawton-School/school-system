import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Calls the JWT-protected Supabase `ai-chat-proxy` Edge Function.
///
/// Provider credentials and system prompts stay server-side. Flutter only
/// sends authenticated user/assistant messages and the allowed application
/// mode.
class AiProxyService {
  final SupabaseClient _client;

  AiProxyService(this._client);

  Future<String> chat({
    required String mode,
    required List<Map<String, String>> messages,
    int maxTokens = 1200,
    double temperature = 0.4,
  }) async {
    if (_client.auth.currentSession == null) {
      throw StateError('An authenticated session is required to use AI.');
    }

    final sanitized = messages
        .where((m) {
          final role = m['role'];
          final content = m['content'];
          return (role == 'user' || role == 'assistant') &&
              content != null &&
              content.trim().isNotEmpty;
        })
        .map((m) => {
              'role': m['role']!,
              'content': m['content']!.trim(),
            })
        .toList(growable: false);

    if (sanitized.isEmpty) {
      throw ArgumentError('At least one AI message is required.');
    }

    final response = await _client.functions.invoke(
      'ai-chat-proxy',
      body: {
        'mode': mode,
        'messages': sanitized,
        'max_tokens': maxTokens,
        'temperature': temperature,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      throw StateError('AI service request failed (${response.status}).');
    }

    final data = response.data;
    if (data is! Map) {
      throw StateError('AI service returned an invalid response.');
    }

    final content = data['content']?.toString().trim();
    if (content == null || content.isEmpty) {
      throw StateError('AI service returned no response text.');
    }

    return content;
  }
}

/// Secure Student AI Tutor implementation.
///
/// Session/message persistence stays in the existing Supabase tables, while
/// generation is delegated to the server-side AI proxy.
class AiTutorService {
  final SupabaseClient _client;
  late final AiProxyService _proxy = AiProxyService(_client);

  AiTutorService(this._client);

  Future<AiSessionModel> getOrCreateSession({
    required String schoolId,
    required String studentProfileId,
    String? subjectId,
  }) async {
    var query = _client
        .from('ai_sessions')
        .select('*, subjects(*)')
        .eq('school_id', schoolId)
        .eq('student_profile_id', studentProfileId)
        .isFilter('deleted_at', null);

    if (subjectId != null) query = query.eq('subject_id', subjectId);

    final existing = await query
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (existing != null) return AiSessionModel.fromMap(existing);

    final created = await _client.from('ai_sessions').insert({
      'school_id': schoolId,
      'student_profile_id': studentProfileId,
      'subject_id': subjectId,
    }).select('*, subjects(*)').single();

    return AiSessionModel.fromMap(created);
  }

  Future<List<AiMessageModel>> getMessages(
    String schoolId,
    String sessionId,
  ) async {
    final response = await _client
        .from('ai_messages')
        .select()
        .eq('school_id', schoolId)
        .eq('session_id', sessionId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);

    return (response as List)
        .map((m) => AiMessageModel.fromMap(
              Map<String, dynamic>.from(m as Map),
            ))
        .toList();
  }

  Future<AiMessageModel> sendUserMessage({
    required String schoolId,
    required String sessionId,
    required String content,
  }) async {
    final response = await _client.from('ai_messages').insert({
      'school_id': schoolId,
      'session_id': sessionId,
      'sender': 'user',
      'content': content.trim(),
    }).select().single();

    return AiMessageModel.fromMap(response);
  }

  Future<AiMessageModel> generateAiResponse({
    required String schoolId,
    required String sessionId,
    required String prompt,
    String? subjectName,
  }) async {
    final persisted = await getMessages(schoolId, sessionId);

    // The screen persists the user's prompt before generation. Use the latest
    // persisted conversation directly so the current prompt is not duplicated.
    final history = persisted.reversed
        .take(12)
        .toList()
        .reversed
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList(growable: true);

    // If another caller invokes generation without first persisting the current
    // prompt, add it once here.
    final normalizedPrompt = prompt.trim();
    final lastContent = history.isEmpty ? null : history.last['content'];
    if (normalizedPrompt.isNotEmpty && lastContent != normalizedPrompt) {
      history.add({'role': 'user', 'content': normalizedPrompt});
    }

    if (subjectName != null && subjectName.trim().isNotEmpty) {
      history.add({
        'role': 'user',
        'content': 'Current focus subject: ${subjectName.trim()}.',
      });
    }

    final responseText = await _proxy.chat(
      mode: 'student_tutor',
      messages: history,
      maxTokens: 800,
      temperature: 0.7,
    );

    final response = await _client.from('ai_messages').insert({
      'school_id': schoolId,
      'session_id': sessionId,
      'sender': 'ai',
      'content': responseText,
    }).select().single();

    return AiMessageModel.fromMap(response);
  }

  Future<StudentLearningProfileModel> getLearningProfile(
    String schoolId,
    String studentProfileId,
  ) async {
    final existing = await _client
        .from('student_learning_profiles')
        .select()
        .eq('school_id', schoolId)
        .eq('student_profile_id', studentProfileId)
        .isFilter('deleted_at', null)
        .maybeSingle();

    if (existing != null) {
      return StudentLearningProfileModel.fromMap(existing);
    }

    // Preserve existing UX without pretending these values were AI-generated.
    // They are an initial empty diagnostic profile until real evaluation data
    // is available.
    final response = await _client.from('student_learning_profiles').insert({
      'school_id': schoolId,
      'student_profile_id': studentProfileId,
      'strengths': <String>[],
      'weaknesses': <String>[],
      'last_evaluated_at': DateTime.now().toIso8601String(),
    }).select().single();

    return StudentLearningProfileModel.fromMap(response);
  }
}

/// Secure Teacher Copilot implementation using the same public API consumed by
/// the existing Teacher AI screen.
class TeacherAiService {
  final SupabaseClient _client;
  late final AiProxyService _proxy = AiProxyService(_client);

  TeacherAiService(this._client);

  SupabaseClient get client => _client;

  Future<String> _callAi({
    required String mode,
    required String userPrompt,
    List<Map<String, String>> conversationHistory = const [],
    int maxTokens = 1200,
    double temperature = 0.4,
  }) async {
    final messages = <Map<String, String>>[
      ...conversationHistory
          .where((m) => m['role'] == 'user' || m['role'] == 'assistant'),
      {'role': 'user', 'content': userPrompt.trim()},
    ];

    return _proxy.chat(
      mode: mode,
      messages: messages,
      maxTokens: maxTokens,
      temperature: temperature,
    );
  }

  Future<String> generateLessonPlan({
    required String subject,
    required String topic,
    required String gradeLevel,
    int durationMinutes = 45,
    String curriculum = 'ZIMSEC / Cambridge',
    String? additionalNotes,
  }) {
    final notes = additionalNotes?.trim();
    return _callAi(
      mode: 'lesson_planner',
      maxTokens: 1400,
      userPrompt: [
        'Create a structured classroom lesson plan.',
        'Subject: $subject',
        'Grade/Level: $gradeLevel',
        'Topic: $topic',
        'Duration: $durationMinutes minutes',
        'Curriculum: $curriculum',
        if (notes != null && notes.isNotEmpty) 'Teacher notes: $notes',
        'Include learning objectives, key concepts, materials, lesson flow, differentiation, formative assessment, and homework/follow-up.',
      ].join('\n'),
    );
  }

  Future<String> generateQuiz({
    required String subject,
    required String topic,
    required String gradeLevel,
    int questionCount = 5,
    String questionType = 'Mixed',
    String difficulty = 'Medium',
  }) {
    return _callAi(
      mode: 'quiz_exam',
      maxTokens: 1400,
      userPrompt: [
        'Create a curriculum-aligned assessment with a complete marking scheme.',
        'Subject: $subject',
        'Topic: $topic',
        'Grade/Level: $gradeLevel',
        'Question count: $questionCount',
        'Question type: $questionType',
        'Difficulty: $difficulty',
        'Clearly show marks for each question and model answers.',
      ].join('\n'),
    );
  }

  Future<String> generateReportRemarks({
    required String studentName,
    required String subject,
    required String grade,
    String performanceTrend = 'Consistent',
    String effort = 'High',
    String? focusAreas,
  }) {
    final focus = focusAreas?.trim();
    return _callAi(
      mode: 'report_remarks',
      maxTokens: 800,
      userPrompt: [
        'Draft three professional report-card remark options.',
        'Student: $studentName',
        'Subject: $subject',
        'Grade/Mark: $grade',
        'Performance trend: $performanceTrend',
        'Effort: $effort',
        if (focus != null && focus.isNotEmpty) 'Focus areas: $focus',
        'Make the options balanced, encouraging, constructive, and action-oriented.',
      ].join('\n'),
    );
  }

  Future<String> chat({
    required String prompt,
    List<Map<String, String>> history = const [],
    String? subject,
  }) {
    final subjectContext = subject?.trim();
    return _callAi(
      mode: 'teacher_copilot',
      conversationHistory: history,
      maxTokens: 900,
      userPrompt: [
        if (subjectContext != null && subjectContext.isNotEmpty)
          'Current teaching subject: $subjectContext.',
        prompt.trim(),
      ].join('\n'),
    );
  }
}
