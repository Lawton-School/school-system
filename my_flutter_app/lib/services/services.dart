// ZivoConnect service barrel.
//
// Legacy non-AI services remain available without forcing a risky rewrite of
// the large historical service file during the security cutover. Security-
// critical Marketplace writes are replaced by the server-authoritative
// compatibility facade below.

export 'legacy_services.dart' hide MarketplaceService;
export 'marketplace_service.dart';
export 'secure_ai_services.dart';
export 'profile_switch_service.dart';
