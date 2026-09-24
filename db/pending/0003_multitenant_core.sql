-- 0003: Multi-tenant core. Append-only — run in your Supabase SQL editor after drizzle 0000-0002.
-- Tiers: Superadmin = has_role(uid,'admin'); Org Admin / Agent = org_members.role.

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TYPE public.org_role AS ENUM ('org_admin', 'agent');
CREATE TYPE public.subscription_status AS ENUM ('ACTIVE', 'GRACE_PERIOD', 'REVOKED');
CREATE TYPE public.message_status AS ENUM ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED');
CREATE TYPE public.conversation_status AS ENUM ('bot', 'human', 'closed');

CREATE TABLE public.organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  round_robin_enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.organizations TO authenticated;
GRANT ALL ON public.organizations TO service_role;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.org_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  role public.org_role NOT NULL DEFAULT 'agent',
  last_assigned_at timestamptz,
  UNIQUE (org_id, user_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.org_members TO authenticated;
GRANT ALL ON public.org_members TO service_role;
ALTER TABLE public.org_members ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_superadmin(_uid uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.has_role(_uid, 'admin')
$$;
CREATE OR REPLACE FUNCTION public.is_org_member(_uid uuid, _org uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.org_members WHERE user_id = _uid AND org_id = _org)
$$;
CREATE OR REPLACE FUNCTION public.is_org_admin(_uid uuid, _org uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.org_members WHERE user_id = _uid AND org_id = _org AND role = 'org_admin')
$$;
GRANT EXECUTE ON FUNCTION public.is_superadmin(uuid), public.is_org_member(uuid, uuid), public.is_org_admin(uuid, uuid) TO authenticated;

CREATE POLICY "org read members" ON public.organizations FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), id) OR public.is_superadmin(auth.uid()));
CREATE POLICY "org admin update" ON public.organizations FOR UPDATE TO authenticated
  USING (public.is_org_admin(auth.uid(), id) OR public.is_superadmin(auth.uid()));
CREATE POLICY "superadmin provisions" ON public.organizations FOR INSERT TO authenticated
  WITH CHECK (public.is_superadmin(auth.uid()));
CREATE POLICY "superadmin deletes" ON public.organizations FOR DELETE TO authenticated
  USING (public.is_superadmin(auth.uid()));

CREATE POLICY "members read team" ON public.org_members FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), org_id) OR public.is_superadmin(auth.uid()));
CREATE POLICY "org admin manages team" ON public.org_members FOR ALL TO authenticated
  USING (public.is_org_admin(auth.uid(), org_id) OR public.is_superadmin(auth.uid()))
  WITH CHECK (public.is_org_admin(auth.uid(), org_id) OR public.is_superadmin(auth.uid()));

CREATE TABLE public.clients_or_projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name text NOT NULL,
  public_api_key text NOT NULL UNIQUE DEFAULT replace(gen_random_uuid()::text, '-', ''),
  allowed_origins text[] NOT NULL DEFAULT '{}',
  system_prompt text NOT NULL DEFAULT '',
  shadow_prompt text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.clients_or_projects TO authenticated;
GRANT ALL ON public.clients_or_projects TO service_role;
ALTER TABLE public.clients_or_projects ENABLE ROW LEVEL SECURITY;
CREATE POLICY "members read clients" ON public.clients_or_projects FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), org_id) OR public.is_superadmin(auth.uid()));
CREATE POLICY "org admin writes clients" ON public.clients_or_projects FOR ALL TO authenticated
  USING (public.is_org_admin(auth.uid(), org_id) OR public.is_superadmin(auth.uid()))
  WITH CHECK (public.is_org_admin(auth.uid(), org_id) OR public.is_superadmin(auth.uid()));

CREATE TABLE public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.clients_or_projects(id) ON DELETE CASCADE,
  assigned_agent_id uuid,
  status public.conversation_status NOT NULL DEFAULT 'bot',
  quality_rating smallint CHECK (quality_rating BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX conversations_org_idx ON public.conversations (org_id, updated_at DESC);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.conversations TO authenticated;
GRANT ALL ON public.conversations TO service_role;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tenant conversations" ON public.conversations FOR ALL TO authenticated
  USING (public.is_org_member(auth.uid(), org_id) OR public.is_superadmin(auth.uid()))
  WITH CHECK (public.is_org_member(auth.uid(), org_id) OR public.is_superadmin(auth.uid()));

CREATE TABLE public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender text NOT NULL CHECK (sender IN ('visitor', 'bot', 'agent', 'shadow')),
  content text NOT NULL,
  status public.message_status NOT NULL DEFAULT 'PENDING',
  prompt_tokens integer NOT NULL DEFAULT 0,
  completion_tokens integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX messages_conv_idx ON public.messages (conversation_id, created_at);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.messages TO authenticated;
GRANT ALL ON public.messages TO service_role;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tenant messages" ON public.messages FOR ALL TO authenticated
  USING (public.is_org_member(auth.uid(), org_id) OR public.is_superadmin(auth.uid()))
  WITH CHECK (public.is_org_member(auth.uid(), org_id) OR public.is_superadmin(auth.uid()));

CREATE TABLE public.automation_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  client_id uuid REFERENCES public.clients_or_projects(id) ON DELETE CASCADE,
  name text NOT NULL,
  trigger text NOT NULL,
  action jsonb NOT NULL DEFAULT '{}',
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.automation_rules TO authenticated;
GRANT ALL ON public.automation_rules TO service_role;
ALTER TABLE public.automation_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "members read rules" ON public.automation_rules FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), org_id) OR public.is_superadmin(auth.uid()));
CREATE POLICY "org admin writes rules" ON public.automation_rules FOR ALL TO authenticated
  USING (public.is_org_admin(auth.uid(), org_id) OR public.is_superadmin(auth.uid()))
  WITH CHECK (public.is_org_admin(auth.uid(), org_id) OR public.is_superadmin(auth.uid()));

CREATE TABLE public.retraining_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  corrected_response text NOT NULL,
  submitted_by uuid NOT NULL,
  approved boolean,
  reviewed_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.retraining_queue TO authenticated;
GRANT ALL ON public.retraining_queue TO service_role;
ALTER TABLE public.retraining_queue ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tenant reads retraining" ON public.retraining_queue FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), org_id) OR public.is_superadmin(auth.uid()));
CREATE POLICY "agents submit corrections" ON public.retraining_queue FOR INSERT TO authenticated
  WITH CHECK (public.is_org_member(auth.uid(), org_id) AND submitted_by = auth.uid());
CREATE POLICY "superadmin approves" ON public.retraining_queue FOR UPDATE TO authenticated
  USING (public.is_superadmin(auth.uid()));

CREATE TABLE public.pricing_tiers (
  id text PRIMARY KEY,
  name text NOT NULL,
  monthly_price numeric(10,2) NOT NULL,
  yearly_price numeric(10,2) NOT NULL,
  message_quota integer NOT NULL
);
GRANT SELECT ON public.pricing_tiers TO anon, authenticated;
GRANT ALL ON public.pricing_tiers TO service_role;
ALTER TABLE public.pricing_tiers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "public reads tiers" ON public.pricing_tiers FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "superadmin writes tiers" ON public.pricing_tiers FOR ALL TO authenticated
  USING (public.is_superadmin(auth.uid())) WITH CHECK (public.is_superadmin(auth.uid()));

-- Chronos: subscriptions are the UTC truth source
CREATE TABLE public.subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.clients_or_projects(id) ON DELETE CASCADE,
  tier_id text NOT NULL REFERENCES public.pricing_tiers(id),
  billing_cycle text NOT NULL CHECK (billing_cycle IN ('monthly', 'yearly')),
  status public.subscription_status NOT NULL DEFAULT 'ACTIVE',
  current_period_start timestamptz NOT NULL DEFAULT now(),
  current_period_end timestamptz NOT NULL,
  rejection_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (current_period_end > current_period_start)
);
CREATE INDEX subscriptions_expiry_idx ON public.subscriptions (current_period_end) WHERE status = 'ACTIVE';
GRANT SELECT ON public.subscriptions TO authenticated;
GRANT ALL ON public.subscriptions TO service_role;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tenant reads subscription" ON public.subscriptions FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), org_id) OR public.is_superadmin(auth.uid()));
CREATE POLICY "superadmin manages subscription" ON public.subscriptions FOR ALL TO authenticated
  USING (public.is_superadmin(auth.uid())) WITH CHECK (public.is_superadmin(auth.uid()));

-- Hourly cron (service role): revoke expired subscriptions
CREATE OR REPLACE FUNCTION public.chronos_revoke_expired()
RETURNS TABLE (client_id uuid) LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE public.subscriptions SET status = 'REVOKED'
  WHERE current_period_end < now() AND status = 'ACTIVE'
  RETURNING subscriptions.client_id
$$;
REVOKE ALL ON FUNCTION public.chronos_revoke_expired() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.chronos_revoke_expired() TO service_role;

-- pgvector knowledge base + semantic cache (HNSW)
CREATE TABLE public.knowledge_chunks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.clients_or_projects(id) ON DELETE CASCADE,
  content text NOT NULL,
  embedding vector(1536) NOT NULL
);
CREATE INDEX knowledge_chunks_hnsw ON public.knowledge_chunks USING hnsw (embedding vector_cosine_ops);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.knowledge_chunks TO authenticated;
GRANT ALL ON public.knowledge_chunks TO service_role;
ALTER TABLE public.knowledge_chunks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tenant knowledge" ON public.knowledge_chunks FOR ALL TO authenticated
  USING (public.is_org_admin(auth.uid(), org_id) OR public.is_superadmin(auth.uid()))
  WITH CHECK (public.is_org_admin(auth.uid(), org_id) OR public.is_superadmin(auth.uid()));

CREATE TABLE public.semantic_cache (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.clients_or_projects(id) ON DELETE CASCADE,
  question text NOT NULL,
  answer text NOT NULL,
  embedding vector(1536) NOT NULL,
  hits integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX semantic_cache_hnsw ON public.semantic_cache USING hnsw (embedding vector_cosine_ops);
GRANT SELECT ON public.semantic_cache TO authenticated;
GRANT ALL ON public.semantic_cache TO service_role;
ALTER TABLE public.semantic_cache ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tenant reads cache" ON public.semantic_cache FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), org_id) OR public.is_superadmin(auth.uid()));

CREATE TABLE public.global_routing_state (
  id smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  llm_provider text NOT NULL DEFAULT 'primary',
  database_target text NOT NULL DEFAULT 'primary',
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, UPDATE ON public.global_routing_state TO authenticated;
GRANT ALL ON public.global_routing_state TO service_role;
ALTER TABLE public.global_routing_state ENABLE ROW LEVEL SECURITY;
CREATE POLICY "superadmin routing" ON public.global_routing_state FOR ALL TO authenticated
  USING (public.is_superadmin(auth.uid())) WITH CHECK (public.is_superadmin(auth.uid()));

-- Seed
INSERT INTO public.pricing_tiers (id, name, monthly_price, yearly_price, message_quota) VALUES
  ('starter', 'Starter', 49, 470, 2000),
  ('growth', 'Growth', 149, 1430, 10000),
  ('scale', 'Scale', 399, 3830, 50000);

INSERT INTO public.global_routing_state (id) VALUES (1);

INSERT INTO public.organizations (id, name, slug) VALUES
  ('00000000-0000-4000-8000-000000000001', 'Northstar Clinic', 'northstar-clinic');

INSERT INTO public.clients_or_projects (id, org_id, name, allowed_origins, system_prompt) VALUES
  ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000001',
   'Northstar Clinic Website', ARRAY['northstarclinic.com'],
   'You are the Northstar Clinic assistant. Help patients book appointments and answer clinic questions.');

INSERT INTO public.subscriptions (org_id, client_id, tier_id, billing_cycle, current_period_start, current_period_end) VALUES
  ('00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000011', 'growth', 'monthly',
   now(), now() + interval '30 days');

INSERT INTO public.automation_rules (org_id, client_id, name, trigger, action) VALUES
  ('00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000011',
   'Escalate frustrated visitors', 'sentiment:negative', '{"type":"handoff","target":"round_robin"}'),
  ('00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000011',
   'Book appointment tool', 'intent:booking', '{"type":"tool","name":"book_appointment"}');
