CREATE TYPE public.app_role AS ENUM ('client','verifier','admin','owner','partner');
CREATE TYPE public.automation_status AS ENUM ('paid','pending_payment','stopped','revoked','suspended','active');
CREATE TYPE public.payment_status AS ENUM ('pending','approved','rejected');

CREATE OR REPLACE FUNCTION public.update_updated_at_column() RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

-- ===== DOMAIN 1: Identity & Access =====
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  company_name text NOT NULL DEFAULT '', company_email text NOT NULL DEFAULT '',
  website_url text NOT NULL DEFAULT '', category text NOT NULL DEFAULT '',
  profile_completed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL DEFAULT 'client', UNIQUE (user_id, role));
CREATE TABLE public.staff_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), email text NOT NULL,
  role public.app_role NOT NULL, status text NOT NULL DEFAULT 'pending',
  invited_by uuid, created_at timestamptz NOT NULL DEFAULT now());

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role) $$;
CREATE OR REPLACE FUNCTION public.is_admin(_user_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role IN ('owner','partner','admin')) $$;
CREATE OR REPLACE FUNCTION public.is_staff(_user_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role IN ('owner','partner','admin','verifier')) $$;

-- ===== DOMAIN 2: Automation & AI Engine =====
CREATE TABLE public.automation_instances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  automation_slug text NOT NULL, website_domain text NOT NULL DEFAULT '', origin text NOT NULL DEFAULT '',
  status public.automation_status NOT NULL DEFAULT 'pending_payment',
  expires_at timestamptz, provisioned_at timestamptz, grace_days integer NOT NULL DEFAULT 3,
  system_prompt text NOT NULL DEFAULT '', prompt_override text NOT NULL DEFAULT '',
  client_id text NOT NULL DEFAULT '', script_token text NOT NULL DEFAULT '',
  business_context text NOT NULL DEFAULT '', billing_plan text NOT NULL DEFAULT 'monthly',
  warning_sent boolean NOT NULL DEFAULT false, killed boolean NOT NULL DEFAULT false,
  conversations_count integer NOT NULL DEFAULT 0, leads_count integer NOT NULL DEFAULT 0,
  webhook_url text NOT NULL DEFAULT '', webhook_secret text NOT NULL DEFAULT encode(gen_random_bytes(24),'hex'),
  webhook_verified boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX ON public.automation_instances(user_id);
CREATE INDEX ON public.automation_instances(script_token);

CREATE OR REPLACE FUNCTION public.owns_automation(_automation_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.automation_instances WHERE id = _automation_id AND user_id = auth.uid()) $$;

CREATE TABLE public.automation_knowledge (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  automation_id uuid NOT NULL REFERENCES public.automation_instances(id) ON DELETE CASCADE,
  scope text NOT NULL DEFAULT 'faq', title text NOT NULL DEFAULT '', content text NOT NULL DEFAULT '',
  version_hash text NOT NULL DEFAULT '', archived boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.tenant_features (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  automation_id uuid NOT NULL REFERENCES public.automation_instances(id) ON DELETE CASCADE,
  feature_key text NOT NULL, enabled boolean NOT NULL DEFAULT false, monthly_price numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (automation_id, feature_key));
CREATE TABLE public.global_prompts (key text PRIMARY KEY, content text NOT NULL DEFAULT '', updated_at timestamptz NOT NULL DEFAULT now());

-- ===== DOMAIN 3: Runtime & CRM =====
CREATE TABLE public.transcripts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  automation_id uuid NOT NULL REFERENCES public.automation_instances(id) ON DELETE CASCADE,
  visitor text NOT NULL DEFAULT '', messages jsonb NOT NULL DEFAULT '[]'::jsonb, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.crm_leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  automation_id uuid NOT NULL REFERENCES public.automation_instances(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT '', email text NOT NULL DEFAULT '', phone text NOT NULL DEFAULT '',
  intent text NOT NULL DEFAULT '', summary text NOT NULL DEFAULT '', source text NOT NULL DEFAULT 'widget',
  lead_score integer NOT NULL DEFAULT 0, trace_id text NOT NULL DEFAULT '',
  webhook_status text NOT NULL DEFAULT 'pending', webhook_response text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.appointment_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  automation_id uuid NOT NULL REFERENCES public.automation_instances(id) ON DELETE CASCADE,
  starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL, status text NOT NULL DEFAULT 'booked',
  visitor_name text NOT NULL DEFAULT '', visitor_email text NOT NULL DEFAULT '', visitor_phone text NOT NULL DEFAULT '',
  notes text NOT NULL DEFAULT '', external_ref text NOT NULL DEFAULT '', trace_id text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.availability_windows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  automation_id uuid NOT NULL REFERENCES public.automation_instances(id) ON DELETE CASCADE,
  weekday integer NOT NULL, start_minute integer NOT NULL, end_minute integer NOT NULL,
  slot_minutes integer NOT NULL DEFAULT 30, timezone text NOT NULL DEFAULT 'UTC', created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.usage_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  automation_id uuid NOT NULL REFERENCES public.automation_instances(id) ON DELETE CASCADE,
  model text NOT NULL DEFAULT '', tokens_in integer NOT NULL DEFAULT 0, tokens_out integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.ticket_escalations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  automation_id uuid NOT NULL REFERENCES public.automation_instances(id) ON DELETE CASCADE,
  reason text NOT NULL DEFAULT '', status text NOT NULL DEFAULT 'open', sentiment numeric NOT NULL DEFAULT 0,
  visitor_contact text NOT NULL DEFAULT '', trace_id text NOT NULL DEFAULT '', transcript jsonb NOT NULL DEFAULT '[]'::jsonb,
  resolved_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.widget_rate_limits (
  automation_id uuid PRIMARY KEY REFERENCES public.automation_instances(id) ON DELETE CASCADE,
  tokens numeric NOT NULL DEFAULT 20, capacity numeric NOT NULL DEFAULT 20, refilled_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.client_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tag text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (user_id, tag));
CREATE INDEX ON public.transcripts(automation_id);
CREATE INDEX ON public.crm_leads(automation_id);
CREATE INDEX ON public.usage_logs(automation_id);

-- ===== DOMAIN 4: Billing & Governance =====
CREATE TABLE public.payment_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  automation_id uuid REFERENCES public.automation_instances(id) ON DELETE CASCADE,
  automation_slug text NOT NULL, billing_plan text NOT NULL CHECK (billing_plan IN ('monthly','yearly')),
  amount numeric(10,2) NOT NULL, payment_method text NOT NULL, transaction_id text NOT NULL, sender_name text NOT NULL,
  origin text NOT NULL DEFAULT '', promo_code text, receipt_url text, rejection_reason text,
  status public.payment_status NOT NULL DEFAULT 'pending',
  submitted_at timestamptz NOT NULL DEFAULT now(), reviewed_at timestamptz, reviewed_by uuid);
CREATE INDEX ON public.payment_submissions(user_id);
CREATE INDEX ON public.payment_submissions(status);
CREATE TABLE public.pricing_plans (
  slug text PRIMARY KEY, name text NOT NULL, monthly_price numeric NOT NULL DEFAULT 0,
  yearly_discount_pct numeric NOT NULL DEFAULT 20, active boolean NOT NULL DEFAULT true, updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.promo_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text NOT NULL UNIQUE, percent_off numeric NOT NULL,
  active boolean NOT NULL DEFAULT true, expires_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.groq_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), label text NOT NULL, key_value text NOT NULL, key_hint text NOT NULL DEFAULT '',
  is_primary boolean NOT NULL DEFAULT false, enabled boolean NOT NULL DEFAULT true, cooldown_until timestamptz,
  request_count integer NOT NULL DEFAULT 0, error_count integer NOT NULL DEFAULT 0, last_used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.groq_failover_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), key_id uuid REFERENCES public.groq_keys(id) ON DELETE SET NULL,
  status_code integer NOT NULL DEFAULT 0, message text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_id uuid, actor_email text NOT NULL DEFAULT '',
  action text NOT NULL, target text NOT NULL DEFAULT '', details jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.app_secrets (key text PRIMARY KEY, value text NOT NULL DEFAULT '', updated_at timestamptz NOT NULL DEFAULT now());

-- updated_at triggers
CREATE TRIGGER t_profiles BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER t_ai BEFORE UPDATE ON public.automation_instances FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER t_ak BEFORE UPDATE ON public.automation_knowledge FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER t_tf BEFORE UPDATE ON public.tenant_features FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER t_leads BEFORE UPDATE ON public.crm_leads FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===== GRANTS =====
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT SELECT ON public.pricing_plans TO anon;

-- ===== RLS =====
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['profiles','user_roles','staff_invites','automation_instances','automation_knowledge','tenant_features','global_prompts','transcripts','crm_leads','appointment_slots','availability_windows','usage_logs','ticket_escalations','widget_rate_limits','client_tags','payment_submissions','pricing_plans','promo_codes','groq_keys','groq_failover_log','audit_log','app_secrets']
  LOOP EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY "Admins manage %1$s" ON public.%1$I FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()))', t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['automation_knowledge','tenant_features','availability_windows']
  LOOP EXECUTE format('CREATE POLICY "Owners manage %1$s" ON public.%1$I FOR ALL TO authenticated USING (public.owns_automation(automation_id)) WITH CHECK (public.owns_automation(automation_id))', t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['crm_leads','transcripts','appointment_slots','ticket_escalations','usage_logs']
  LOOP EXECUTE format('CREATE POLICY "Owners read %1$s" ON public.%1$I FOR SELECT TO authenticated USING (public.owns_automation(automation_id))', t);
    EXECUTE format('CREATE POLICY "Owners insert %1$s" ON public.%1$I FOR INSERT TO authenticated WITH CHECK (public.owns_automation(automation_id))', t);
    EXECUTE format('CREATE POLICY "Owners update %1$s" ON public.%1$I FOR UPDATE TO authenticated USING (public.owns_automation(automation_id)) WITH CHECK (public.owns_automation(automation_id))', t);
  END LOOP;
END $$;

-- user_roles: no is_admin() in these policies (direct owner/partner checks only)
DROP POLICY "Admins manage user_roles" ON public.user_roles;
CREATE POLICY "Users read own roles" ON public.user_roles FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Owners and partners read roles" ON public.user_roles FOR SELECT TO authenticated USING (public.has_role(auth.uid(),'owner') OR public.has_role(auth.uid(),'partner'));
CREATE POLICY "Owners and partners remove non-owner roles" ON public.user_roles FOR DELETE TO authenticated USING ((public.has_role(auth.uid(),'owner') OR public.has_role(auth.uid(),'partner')) AND role <> 'owner');

CREATE POLICY "Users manage own profile" ON public.profiles FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Staff read profiles" ON public.profiles FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Users read own automations" ON public.automation_instances FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users create own automations" ON public.automation_instances FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id AND status = 'pending_payment');
CREATE POLICY "Users update own automations" ON public.automation_instances FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Staff read automations" ON public.automation_instances FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Users read own payments" ON public.payment_submissions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users submit own payments" ON public.payment_submissions FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id AND status = 'pending');
CREATE POLICY "Staff read payments" ON public.payment_submissions FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Anyone reads active plans" ON public.pricing_plans FOR SELECT TO anon, authenticated USING (active);
CREATE POLICY "Users read own tags" ON public.client_tags FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Staff read audit" ON public.audit_log FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));

-- ===== Signup: strictly 'client' =====
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (user_id, company_email) VALUES (NEW.id, COALESCE(NEW.email,'')) ON CONFLICT (user_id) DO NOTHING;
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'client') ON CONFLICT DO NOTHING;
  RETURN NEW;
END; $$;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ===== RPCs =====
CREATE OR REPLACE FUNCTION public.claim_staff_invite() RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE inv record; em text;
BEGIN
  SELECT email INTO em FROM auth.users WHERE id = auth.uid();
  IF em IS NULL THEN RETURN ''; END IF;
  SELECT * INTO inv FROM public.staff_invites WHERE lower(email) = lower(em) AND status = 'pending' ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN ''; END IF;
  INSERT INTO public.user_roles (user_id, role) VALUES (auth.uid(), inv.role) ON CONFLICT DO NOTHING;
  UPDATE public.staff_invites SET status = 'claimed' WHERE id = inv.id;
  INSERT INTO public.audit_log (actor_id, actor_email, action, target) VALUES (auth.uid(), em, 'staff_invite_claimed', inv.role::text);
  RETURN inv.role::text;
END; $$;

CREATE OR REPLACE FUNCTION public.review_payment(_payment_id uuid, _approve boolean, _reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE p record; days int;
BEGIN
  IF NOT public.is_staff(auth.uid()) THEN RAISE EXCEPTION 'Staff access required'; END IF;
  SELECT * INTO p FROM public.payment_submissions WHERE id = _payment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Payment not found'; END IF;
  IF p.status <> 'pending' THEN RAISE EXCEPTION 'Payment already reviewed'; END IF;
  IF _approve THEN
    days := CASE WHEN p.billing_plan = 'yearly' THEN 365 ELSE 30 END;
    UPDATE public.payment_submissions SET status='approved', reviewed_at=now(), reviewed_by=auth.uid() WHERE id=_payment_id;
    IF p.automation_id IS NOT NULL THEN
      UPDATE public.automation_instances SET status='active', warning_sent=false, killed=false, billing_plan=p.billing_plan,
        expires_at = GREATEST(COALESCE(expires_at, now()), now()) + make_interval(days => days),
        client_id = CASE WHEN client_id = '' THEN 'cl_' || encode(gen_random_bytes(8),'hex') ELSE client_id END,
        script_token = CASE WHEN script_token = '' THEN 'st_' || encode(gen_random_bytes(16),'hex') ELSE script_token END,
        provisioned_at = COALESCE(provisioned_at, now())
      WHERE id = p.automation_id;
    END IF;
  ELSE
    IF coalesce(trim(_reason),'') = '' THEN RAISE EXCEPTION 'A reason is required to reject'; END IF;
    UPDATE public.payment_submissions SET status='rejected', rejection_reason=_reason, reviewed_at=now(), reviewed_by=auth.uid() WHERE id=_payment_id;
  END IF;
  INSERT INTO public.audit_log (actor_id, action, target, details)
  VALUES (auth.uid(), CASE WHEN _approve THEN 'payment_approved' ELSE 'payment_rejected' END, _payment_id::text, jsonb_build_object('reason', _reason, 'amount', p.amount));
END; $$;

CREATE OR REPLACE FUNCTION public.provision_automation(_automation_id uuid) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE cid text;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RAISE EXCEPTION 'Admin access required'; END IF;
  UPDATE public.automation_instances SET status='active', killed=false, provisioned_at=now(),
    expires_at = COALESCE(expires_at, now() + interval '30 days'),
    client_id = CASE WHEN client_id = '' THEN 'cl_' || encode(gen_random_bytes(8),'hex') ELSE client_id END,
    script_token = CASE WHEN script_token = '' THEN 'st_' || encode(gen_random_bytes(16),'hex') ELSE script_token END
  WHERE id = _automation_id RETURNING client_id INTO cid;
  IF cid IS NULL THEN RAISE EXCEPTION 'Automation not found'; END IF;
  INSERT INTO public.audit_log (actor_id, action, target) VALUES (auth.uid(), 'automation_provisioned', _automation_id::text);
  RETURN cid;
END; $$;

CREATE OR REPLACE FUNCTION public.run_subscription_lifecycle() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin(auth.uid()) THEN RAISE EXCEPTION 'Admin access required'; END IF;
  UPDATE public.automation_instances SET warning_sent = true
    WHERE status IN ('active','paid') AND NOT warning_sent AND expires_at IS NOT NULL AND expires_at < now() + interval '3 days';
  UPDATE public.automation_instances SET status = 'suspended'
    WHERE status IN ('active','paid') AND expires_at IS NOT NULL AND expires_at + make_interval(days => grace_days) < now();
  INSERT INTO public.audit_log (actor_id, action) VALUES (auth.uid(), 'lifecycle_run');
END; $$;

CREATE OR REPLACE FUNCTION public.validate_promo(_code text) RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT percent_off FROM public.promo_codes WHERE upper(code) = upper(_code) AND active AND (expires_at IS NULL OR expires_at > now()) LIMIT 1 $$;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon, public;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role), public.is_admin(uuid), public.is_staff(uuid), public.owns_automation(uuid),
  public.claim_staff_invite(), public.review_payment(uuid, boolean, text), public.provision_automation(uuid),
  public.run_subscription_lifecycle(), public.validate_promo(text) TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

INSERT INTO public.pricing_plans (slug, name, monthly_price) VALUES
 ('voice-sms-receptionist','AI Voice & SMS Receptionist',499),
 ('lead-capture-qualifier','AI Lead Capture & Smart Qualifier',299),
 ('knowledge-base-support','AI Knowledge Base Support Agent',349),
 ('social-dm-assistant','AI Social DM & Messaging Assistant',299),
 ('appointment-recovery','AI Appointment & No-Show Recovery',399),
 ('review-collector','AI Reputation & Review Collector',199);