-- হিসেবের খাতা (ajkerhiseb) — Supabase schema
-- Supabase Dashboard → SQL Editor → New Query → এই পুরো ফাইল পেস্ট → Run
-- ফ্রি প্ল্যানেই চলবে।
-- নতুন প্রজেক্টে পুরোটা একবারেই চলবে। পুরোনো প্রজেক্টে (আগের schema.sql
-- চালানো থাকলে) ALTER TABLE / CREATE TABLE IF NOT EXISTS অংশগুলো
-- নিরাপদে পুরোনো টেবিলে ক্যাটাগরি ও বাজেট যোগ করে দেবে।

-- লেনদেনের টেবিল। id টেক্সট রাখা হয়েছে যাতে ব্রাউজারের পুরোনো
-- localStorage আইডি (seed-e1 … seed-e22, e<timestamp>) সরাসরি upsert করা যায়।
create table if not exists public.transactions (
  id text primary key,
  date date not null,
  item text not null,
  type text not null check (type in ('income', 'expense', 'bank')),
  amount numeric not null check (amount > 0),
  note text,
  category text not null default 'অন্যান্য',
  created_at timestamptz not null default now()
);

-- পুরোনো টেবিলে ক্যাটাগরি কলাম না থাকলে যোগ করুন (নতুন প্রজেক্টে এটি no-op)।
alter table public.transactions
  add column if not exists category text not null default 'অন্যান্য';

-- ক্যাটাগরি: বাজার, ঔষধ, ব্যক্তিগত, যাতায়াত, বাড়ি ভাড়া, বিল, শিক্ষা, অন্যান্য
-- (অন্য মান এলে অ্যাপ সেটিকে 'অন্যান্য' হিসেবে দেখাবে।)

-- তারিখ দিয়ে সাজানো/ছাঁকার জন্য ইনডেক্স
create index if not exists transactions_date_idx on public.transactions (date desc);
create index if not exists transactions_category_idx on public.transactions (category);

-- মাসিক বাজেটের টেবিল। month হলো 'YYYY-MM' (যেমন '2026-11')।
-- কোনো ডিফল্ট বাজেট নেই — ব্যবহারকারী অ্যাপ থেকে যে মাসের বাজেট
-- নির্ধারণ করবেন, সেটিই এখানে থাকবে।
create table if not exists public.budgets (
  month text primary key,
  amount numeric not null check (amount > 0),
  updated_at timestamptz not null default now()
);

-- বাজেট লিস্টের টেবিল (আলাদা বাজেটের তালিকা)। month হলো 'YYYY-MM'।
-- নাম, ক্যাটাগরি, বাজেটের অংক, মাস — খালি শুরু হয়, কোনো ডিফল্ট আইটেম নেই।
create table if not exists public.budget_items (
  id text primary key,
  name text not null,
  category text not null default 'অন্যান্য',
  amount numeric not null check (amount > 0),
  month text not null,
  created_at timestamptz not null default now()
);
create index if not exists budget_items_month_idx on public.budget_items (month);

-- Row Level Security চালু (Supabase-এ ডিফল্টভাবে RLS বন্ধ থাকে না,
-- তবে টেবিল বানানোর পর এটি চালু করা নিরাপত্তার নিয়ম)।
alter table public.transactions enable row level security;
alter table public.budgets enable row level security;
alter table public.budget_items enable row level security;

-- ব্যক্তিগত একক ব্যবহারকারীর খাতা: anon key দিয়ে পড়া/লেখা যাবে।
-- ⚠️ সতর্কতা: এটি সবার জন্য উন্মুক্ত নয়, তবে anon key জানা যে কেউ
-- এই প্রজেক্টের টেবিলে পড়তে/লিখতে পারবে — তাই anon key গোপনে রাখুন
-- এবং প্রজেক্টটি অন্য কারো সাথে শেয়ার করবেন না। লগইন-ভিত্তিক
-- (auth.uid()) নিয়ম চাইলে পরে policy বদলানো যাবে।
drop policy if exists "transactions_all_anon" on public.transactions;
create policy "transactions_all_anon" on public.transactions
  for all to anon using (true) with check (true);

drop policy if exists "budgets_all_anon" on public.budgets;
create policy "budgets_all_anon" on public.budgets
  for all to anon using (true) with check (true);

drop policy if exists "budget_items_all_anon" on public.budget_items;
create policy "budget_items_all_anon" on public.budget_items
  for all to anon using (true) with check (true);
