// ZivoConnect service barrel.
//
// Legacy non-AI services remain available without forcing a risky rewrite of
// the large historical service file during the security cutover. Security-
// critical Marketplace and Finance writes are replaced by server-authoritative
// compatibility facades below.

export 'legacy_services.dart' hide MarketplaceService, SchoolFinanceService;
export 'marketplace_service.dart';
export 'finance_service.dart';
export 'secure_ai_services.dart';
export 'profile_switch_service.dart';
