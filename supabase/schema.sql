-- হিসেবের খাতা (ajkerhiseb) — Supabase schema
-- Supabase Dashboard → SQL Editor → New Query → এই পুরো ফাইল পেস্ট → Run
-- ফ্রি প্ল্যানেই চলবে।

-- লেনদেনের টেবিল। id টেক্সট রাখা হয়েছে যাতে ব্রাউজারের পুরোনো
-- localStorage আইডি (seed-e1 … seed-e22, e<timestamp>) সরাসরি upsert করা যায়।
create table if not exists public.transactions (
  id text primary key,
  date date not null,
  item text not null,
  type text not null check (type in ('income', 'expense', 'bank')),
  amount numeric not null check (amount > 0),
  note text,
  created_at timestamptz not null default now()
);

-- তারিখ দিয়ে সাজানো/ছাঁকার জন্য ইনডেক্স
create index if not exists transactions_date_idx on public.transactions (date desc);

-- Row Level Security চালু (Supabase-এ ডিফল্টভাবে RLS বন্ধ থাকে না,
-- তবে টেবিল বানানোর পর এটি চালু করা নিরাপত্তার নিয়ম)।
alter table public.transactions enable row level security;

-- ব্যক্তিগত একক ব্যবহারকারীর খাতা: anon key দিয়ে পড়া/লেখা যাবে।
-- ⚠️ সতর্কতা: এটি সবার জন্য উন্মুক্ত নয়, তবে anon key জানা যে কেউ
-- এই প্রজেক্টের টেবিলে পড়তে/লিখতে পারবে — তাই anon key গোপনে রাখুন
-- এবং প্রজেক্টটি অন্য কারো সাথে শেয়ার করবেন না। লগইন-ভিত্তিক
-- (auth.uid()) নিয়ম চাইলে পরে policy বদলানো যাবে।
drop policy if exists "transactions_all_anon" on public.transactions;
create policy "transactions_all_anon" on public.transactions
  for all to anon using (true) with check (true);
