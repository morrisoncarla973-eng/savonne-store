-- Migration 001: initial schema for Savonne storefront + admin
create extension if not exists "pgcrypto";

-- Products / catalogue
create table if not exists public.products (
  id text primary key,
  name text not null,
  category text not null,
  note text,
  price numeric(10,2) not null default 0,
  stock integer not null default 0,
  description text,
  image_url text,
  sku text,
  tag text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Customers (storefront accounts)
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null unique,
  password_hash text,
  created_at timestamptz not null default now()
);

-- Orders
create table if not exists public.orders (
  id text primary key,
  customer_id uuid references public.customers(id) on delete set null,
  customer_name text,
  customer_email text,
  total numeric(10,2) not null default 0,
  status text not null default 'Awaiting payment',
  placed_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id text not null references public.orders(id) on delete cascade,
  product_id text references public.products(id) on delete set null,
  product_name text,
  quantity integer not null default 1,
  unit_price numeric(10,2) not null default 0
);

-- Inventory (stock on hand + sku) - mirror of products but explicit
-- (products already carries stock/sku; no separate table needed)

-- Promotions / discount codes
create table if not exists public.promotions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  type text not null check (type in ('percent','amount')),
  value numeric(10,2) not null,
  uses integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Newsletter subscribers
create table if not exists public.subscribers (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  source text,
  joined_at timestamptz not null default now()
);

-- Customer messages / contact inbox
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  customer_name text,
  email text,
  body text not null,
  status text not null default 'unread',
  received_at timestamptz not null default now()
);

-- Site settings (single row)
create table if not exists public.site_settings (
  id integer primary key default 1,
  store_name text,
  tagline text,
  currency_symbol text,
  hero_image text,
  story_video_url text,
  story_video_mode text,
  delivery_text text,
  contact_email text,
  phone text,
  whatsapp text,
  instagram text,
  tiktok text,
  facebook text,
  x_handle text,
  updated_at timestamptz not null default now(),
  constraint site_settings_singleton check (id = 1)
);

-- Page copy
create table if not exists public.page_copy (
  id integer primary key default 1,
  about_heading text,
  about_copy text,
  benefits_heading text,
  contact_heading text,
  contact_copy text,
  newsletter_title text,
  newsletter_copy text,
  benefit_titles text[],
  benefit_copies text[],
  updated_at timestamptz not null default now(),
  constraint page_copy_singleton check (id = 1)
);

-- Campaigns / banner
create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  title text,
  body text,
  image_url text,
  cta_label text,
  cta_url text,
  style text,
  enabled boolean not null default false,
  revision integer not null default 0,
  updated_at timestamptz not null default now()
);

-- Admin users
create table if not exists public.admin_users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  password_hash text not null,
  created_at timestamptz not null default now()
);

-- RLS
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.promotions enable row level security;
alter table public.subscribers enable row level security;
alter table public.messages enable row level security;
alter table public.site_settings enable row level security;
alter table public.page_copy enable row level security;
alter table public.campaigns enable row level security;
alter table public.admin_users enable row level security;

-- Public read for products
create policy "products public read" on public.products for select using (true);
-- Public read for site settings / page copy
create policy "site_settings public read" on public.site_settings for select using (true);
create policy "page_copy public read" on public.page_copy for select using (true);
-- Subscribers insert
create policy "subscribers public insert" on public.subscribers for insert with check (true);
-- Messages insert
create policy "messages public insert" on public.messages for insert with check (true);
-- Orders insert
create policy "orders public insert" on public.orders for insert with check (true);
create policy "order_items public insert" on public.order_items for insert with check (true);

-- updated_at trigger
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

create trigger products_touch before update on public.products for each row execute function public.touch_updated_at();
create trigger orders_touch before update on public.orders for each row execute function public.touch_updated_at();
create trigger site_settings_touch before update on public.site_settings for each row execute function public.touch_updated_at();
create trigger page_copy_touch before update on public.page_copy for each row execute function public.touch_updated_at();
create trigger campaigns_touch before update on public.campaigns for each row execute function public.touch_updated_at();

-- Seed default site settings + page copy
insert into public.site_settings (id, store_name, tagline, currency_symbol, delivery_text)
values (1, 'SAVONNE', 'HANDMADE SOAP ·', '$', 'Delivery is currently available within Ghana.')
on conflict (id) do nothing;

insert into public.page_copy (id, about_heading, benefits_heading, contact_heading, contact_copy, newsletter_title, newsletter_copy, benefit_titles, benefit_copies)
values (1, 'Made with care.\nRooted in ritual.', 'Goodness in every bar.', 'A note to\nSavonne.', 'Questions about a soap or an order? Leave us a message.', 'Good things in your inbox.', 'New batches, small rituals, and thoughtful notes from Savonne. No noise, promise.',
  array['Plant-minded','Gentle by nature','Made in small batches','Less, but better'],
  array['Thoughtful oils and botanicals chosen with care.','Comforting everyday cleansing and a soft lather.','Each bar is carefully made, cut, and finished.','Simple rituals that make room for a little calm.'])
on conflict (id) do nothing;
