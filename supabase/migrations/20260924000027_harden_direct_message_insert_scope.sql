-- Restrict direct-message inserts to the active profile and active school.
-- This closes a gap where the previous policy verified only that the sender
-- belonged to the authenticated user, without requiring the recipient to be
-- in the same active school.

drop policy if exists messages_write on public.direct_messages;

create policy messages_write
on public.direct_messages
for insert
to authenticated
with check (
  school_id = public.get_active_school_id()
  and sender_profile_id = public.get_active_profile_id()
  and exists (
    select 1
    from public.profiles recipient
    where recipient.id = recipient_profile_id
      and recipient.school_id = public.get_active_school_id()
      and recipient.deleted_at is null
  )
);
