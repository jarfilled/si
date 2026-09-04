create table if not exists public.womens_health_email_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 100),
  email text not null check (char_length(trim(email)) between 3 and 320),
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists womens_health_email_contacts_user_email_idx
  on public.womens_health_email_contacts (user_id, lower(email));

alter table public.womens_health_email_contacts enable row level security;

create policy "Users can read their womens health email contacts"
  on public.womens_health_email_contacts
  for select
  using (auth.uid() = user_id);

create policy "Users can add their womens health email contacts"
  on public.womens_health_email_contacts
  for insert
  with check (auth.uid() = user_id);

create policy "Users can update their womens health email contacts"
  on public.womens_health_email_contacts
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their womens health email contacts"
  on public.womens_health_email_contacts
  for delete
  using (auth.uid() = user_id);

create table if not exists public.womens_health_email_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  contact_email text not null,
  log_date date not null,
  sent_at timestamptz not null default now(),
  unique (user_id, lower(contact_email), log_date)
);

alter table public.womens_health_email_deliveries enable row level security;

create policy "Users can read their womens health email delivery history"
  on public.womens_health_email_deliveries
  for select
  using (auth.uid() = user_id);

create policy "Users can record their womens health email deliveries"
  on public.womens_health_email_deliveries
  for insert
  with check (auth.uid() = user_id);
