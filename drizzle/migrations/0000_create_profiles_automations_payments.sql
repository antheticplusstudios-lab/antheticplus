CREATE TYPE public.app_role AS ENUM ('client', 'verifier', 'admin');
CREATE TYPE public.automation_status AS ENUM ('paid', 'pending_payment', 'stopped', 'revoked');
CREATE TYPE public.payment_status AS ENUM ('pending', 'approved', 'rejected');

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE,
  company_name text NOT NULL DEFAULT '',
  company_email text NOT NULL DEFAULT '',
  website_url text NOT NULL DEFAULT '',
  category text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own profile" ON public.profiles FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  role public.app_role NOT NULL DEFAULT 'client',
  UNIQUE (user_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own roles" ON public.user_roles FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;

CREATE TABLE public.automation_instances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  automation_slug text NOT NULL,
  website_domain text NOT NULL,
  status public.automation_status NOT NULL DEFAULT 'pending_payment',
  expires_at timestamptz,
  system_prompt text NOT NULL DEFAULT '',
  client_id text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.automation_instances TO authenticated;
GRANT ALL ON public.automation_instances TO service_role;
ALTER TABLE public.automation_instances ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own automations" ON public.automation_instances FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Staff read automations" ON public.automation_instances FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'verifier') OR public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.payment_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  automation_id uuid REFERENCES public.automation_instances(id) ON DELETE CASCADE,
  automation_slug text NOT NULL,
  billing_plan text NOT NULL CHECK (billing_plan IN ('monthly', 'yearly')),
  amount numeric(10,2) NOT NULL,
  payment_method text NOT NULL,
  transaction_id text NOT NULL,
  sender_name text NOT NULL,
  status public.payment_status NOT NULL DEFAULT 'pending',
  submitted_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.payment_submissions TO authenticated;
GRANT ALL ON public.payment_submissions TO service_role;
ALTER TABLE public.payment_submissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own payments" ON public.payment_submissions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users submit own payments" ON public.payment_submissions FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id AND status = 'pending');
CREATE POLICY "Users update pending payments" ON public.payment_submissions FOR UPDATE TO authenticated USING (auth.uid() = user_id AND status = 'pending') WITH CHECK (auth.uid() = user_id AND status = 'pending');
CREATE POLICY "Staff read payments" ON public.payment_submissions FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'verifier') OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Staff review payments" ON public.payment_submissions FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'verifier') OR public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'verifier') OR public.has_role(auth.uid(), 'admin'));

CREATE INDEX automation_instances_user_id_idx ON public.automation_instances(user_id);
CREATE INDEX payment_submissions_user_id_idx ON public.payment_submissions(user_id);
CREATE INDEX payment_submissions_status_idx ON public.payment_submissions(status);