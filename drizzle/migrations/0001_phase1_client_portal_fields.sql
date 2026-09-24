ALTER TYPE public.automation_status ADD VALUE IF NOT EXISTS 'suspended';

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.automation_instances ADD COLUMN IF NOT EXISTS business_context TEXT NOT NULL DEFAULT '';
ALTER TABLE public.automation_instances ADD COLUMN IF NOT EXISTS billing_plan TEXT NOT NULL DEFAULT 'monthly';
ALTER TABLE public.automation_instances ADD COLUMN IF NOT EXISTS warning_sent BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.automation_instances ADD COLUMN IF NOT EXISTS conversations_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.automation_instances ADD COLUMN IF NOT EXISTS leads_count INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.payment_submissions ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE public.payment_submissions ADD COLUMN IF NOT EXISTS receipt_url TEXT;
