alter table public.womens_health_profiles
  add column if not exists share_daily_mood_pain_enabled boolean not null default false;

create table if not exists public.womens_health_share_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  email text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  constraint womens_health_share_contacts_name_check check (char_length(trim(name)) between 1 and 100),
  constraint womens_health_share_contacts_email_check check (email ~* '^[^\s@]+@[^\s@]+\.[^\s@]+$')
);

create index if not exists womens_health_share_contacts_user_id_idx
  on public.womens_health_share_contacts(user_id);

alter table public.womens_health_share_contacts enable row level security;

create policy "Users can view their own women health share contacts"
  on public.womens_health_share_contacts
  for select
  using (auth.uid() = user_id);

create policy "Users can add their own women health share contacts"
  on public.womens_health_share_contacts
  for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own women health share contacts"
  on public.womens_health_share_contacts
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their own women health share contacts"
  on public.womens_health_share_contacts
  for delete
  using (auth.uid() = user_id);
