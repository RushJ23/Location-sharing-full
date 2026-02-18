-- RPC that takes user_ids and returns always_share_locations for those users.
-- Uses SECURITY DEFINER so RLS doesn't block. Client passes IDs from their contacts.
CREATE OR REPLACE FUNCTION public.get_always_share_locations_for_users(p_user_ids uuid[])
RETURNS SETOF public.always_share_locations
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT * FROM public.always_share_locations
  WHERE user_id = ANY(p_user_ids);
$$;

GRANT EXECUTE ON FUNCTION public.get_always_share_locations_for_users(uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_always_share_locations_for_users(uuid[]) TO service_role;
