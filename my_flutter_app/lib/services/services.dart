// ZivoConnect service barrel.
//
// Legacy services remain available without forcing a risky rewrite of the
// large historical service file during the security cutover. Security-critical
// Marketplace, Finance, Operations, Gradebook/Report Cards, Super Admin school
// operations and AI paths are replaced by hardened server-authoritative facades
// below.

export 'legacy_services.dart'
    hide
        MarketplaceService,
        SchoolFinanceService,
        SchoolOperationsService,
        AcademicGradebookService,
        SchoolService;
export 'marketplace_service.dart';
export 'finance_service.dart';
export 'operations_service.dart';
export 'academic_gradebook_service.dart';
export 'school_service.dart';
export 'secure_ai_services.dart';
export 'profile_switch_service.dart';
