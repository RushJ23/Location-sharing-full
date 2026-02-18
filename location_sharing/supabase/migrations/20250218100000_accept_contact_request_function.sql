-- Accept contact request in a single transaction with SECURITY DEFINER so both
-- contact rows can be inserted (RLS would block the "other" user's row from client).
CREATE OR REPLACE FUNCTION public.accept_contact_request(
  p_request_id uuid,
  p_acceptor_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from_user_id uuid;
BEGIN
  SELECT from_user_id INTO v_from_user_id
  FROM public.contact_requests
  WHERE id = p_request_id
    AND to_user_id = p_acceptor_user_id
    AND status = 'pending';

  IF v_from_user_id IS NULL THEN
    RAISE EXCEPTION 'Contact request not found or not pending';
  END IF;

  UPDATE public.contact_requests
  SET status = 'accepted', updated_at = now()
  WHERE id = p_request_id;

  INSERT INTO public.contacts (user_id, contact_user_id, layer)
  VALUES
    (p_acceptor_user_id, v_from_user_id, 1),
    (v_from_user_id, p_acceptor_user_id, 1);
END;
$$;

-- Allow authenticated users to call this (they can only accept requests sent to them).
GRANT EXECUTE ON FUNCTION public.accept_contact_request(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_contact_request(uuid, uuid) TO service_role;
