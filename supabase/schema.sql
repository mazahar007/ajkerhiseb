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
  date date,
  created_at timestamptz not null default now()
);
create index if not exists budget_items_month_idx on public.budget_items (month);
create index if not exists budget_items_date_idx on public.budget_items (date desc);

-- পুরোনো টেবিলে তারিখ কলাম না থাকলে যোগ করুন (নতুন প্রজেক্টে এটি no-op)।
-- তারিখ না দেওয়া পুরোনো আইটেমের date NULL থাকবে — অ্যাপ সেগুলোকে
-- ওই মাসের ১ তারিখ (month + '-01') হিসেবে দেখাবে।
alter table public.budget_items
  add column if not exists date date;

-- মাল্টি-অ্যাকাউন্ট (লোকাল): অ্যাপে প্রতিটা অ্যাকাউন্টের নিজের আলাদা খাতা
-- থাকে, তবে তা এখনো শুধু ওই ব্রাউজারের localStorage-এ (অ্যাকাউন্ট-আইডি
-- দিয়ে আলাদা চাবিতে)। Supabase-এ সব অ্যাকাউন্টের ডেটা আপাতত একটাই
-- ভাগ করা লেজারে যায় — সার্ভারে প্রতি-ব্যবহারকারী আলাদা করতে নিচের
-- user_id কলাম রাখা হলো; ভবিষ্যতে অ্যাপ user_id পাঠাতে শুরু করলে
-- (auth.uid() বা লোকাল অ্যাকাউন্ট-আইডি) এই কলামে ছাঁকা যাবে। কোনো
-- আসল চাবি বা অ্যাকাউন্ট এখানে বানানো হয়নি।
alter table public.transactions add column if not exists user_id text;
alter table public.budgets add column if not exists user_id text;
alter table public.budget_items add column if not exists user_id text;
create index if not exists transactions_user_idx on public.transactions (user_id);
create index if not exists budget_items_user_idx on public.budget_items (user_id);

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

-- লগইন (Supabase Auth): ইমেইল/পাসওয়ার্ড লগইনের জন্য আলাদা টেবিল
-- লাগে না — Supabase-এর নিজের auth.users টেবিল ব্যবহার হয়। অ্যাপের
-- পিন লগইন আলাদাভাবে ব্রাউজারে (localStorage-এ হ্যাশ আকারে) চলে,
-- তাই এই schema-তে Auth-এর জন্য কিছু যোগ করতে হয় না। ভবিষ্যতে শুধু
-- লগইন করা ব্যবহারকারীর ডেটা দেখাতে চাইলে উপরের anon policy-গুলোর
-- বদলে authenticated + auth.uid() ভিত্তিক policy বসাতে হবে।
-- লোকাল মাল্টি-অ্যাকাউন্ট: একই ব্রাউজারে একাধিক অ্যাকাউন্ট (প্রতিটার
-- নিজের পিন আর আলাদা খাতা) চলে — তবে সেগুলো শুধু ওই ব্রাউজারেই থাকে।
-- অন্য ডিভাইসে একই অ্যাকাউন্ট পেতে হলে Supabase সিঙ্ক + উপরের user_id
-- কলামে অ্যাকাউন্ট আলাদা করতে হবে (এখনো অ্যাপ user_id পাঠায় না)।
