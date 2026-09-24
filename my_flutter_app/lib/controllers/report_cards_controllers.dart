import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../repositories/report_cards_repository.dart';

final reportCardsRepositoryProvider = Provider<ReportCardsRepository>((ref) {
  return ReportCardsRepository(
    client: ref.watch(supabaseClientProvider),
    rpc: ref.watch(rpcClientProvider),
  );
});

final reportCardsOverviewProvider = FutureProvider.autoDispose.family<
    Map<String, dynamic>,
    ({String academicYearId, String termId, String classSectionId})>(
  (ref, args) async {
    return ref.watch(reportCardsRepositoryProvider).fetchOverview(
          academicYearId: args.academicYearId,
          termId: args.termId,
          classSectionId: args.classSectionId,
        );
  },
);
