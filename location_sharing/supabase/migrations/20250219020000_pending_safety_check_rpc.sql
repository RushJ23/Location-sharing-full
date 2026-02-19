-- RPC: Register a pending safety check (called when curfew notification is scheduled/shown)
CREATE OR REPLACE FUNCTION public.register_pending_safety_check(
  p_schedule_id uuid DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_expires_at timestamptz;
  v_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_expires_at := COALESCE(p_expires_at, now() + interval '5 minutes');

  INSERT INTO public.pending_safety_checks (user_id, schedule_id, expires_at)
  VALUES (v_user_id, p_schedule_id, v_expires_at)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- RPC: Mark pending safety check as responded (called when user taps I'm safe or I need help)
CREATE OR REPLACE FUNCTION public.respond_to_safety_check(
  p_schedule_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.pending_safety_checks
  SET responded_at = now()
  WHERE user_id = v_user_id
    AND responded_at IS NULL
    AND (p_schedule_id IS NULL OR schedule_id = p_schedule_id);
END;
$$;
