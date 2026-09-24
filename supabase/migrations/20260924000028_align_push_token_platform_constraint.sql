-- Keep push_tokens.platform aligned with register_push_token().
-- This does not configure or claim push delivery; FCM/APNs credentials and
-- provider integration remain an external dependency.

ALTER TABLE public.push_tokens
  DROP CONSTRAINT IF EXISTS push_tokens_platform_check;

ALTER TABLE public.push_tokens
  ADD CONSTRAINT push_tokens_platform_check
  CHECK (platform IN ('android','ios','web','windows','macos','linux'));
