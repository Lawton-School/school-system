# ZivoConnect EMS — Supabase Cloud Deployment Guide

This document explains how to connect your ZivoConnect EMS platform to a **Supabase Cloud** project (free tier supported).

> **Note:** Local Docker-based Supabase is optional and not required. For development and production, Supabase Cloud is the recommended approach.

---

## Step 1: Create a Supabase Project

1. Go to [https://supabase.com](https://supabase.com) and sign up or log in.
2. Click **"New Project"** and fill in:
   - **Project Name:** `ZivoConnect EMS`
   - **Database Password:** (choose a strong password — save it!)
   - **Region:** Choose closest to your users (e.g., Africa for South African schools)
3. Wait ~2 minutes for the project to initialize.

---

## Step 2: Retrieve Your API Keys

1. Go to your project → **Settings** → **API**.
2. Copy:
   - **Project URL** → `https://xxxx.supabase.co`
   - **anon / public key** → Long JWT string starting with `eyJ...`
3. Open [`lib/core/constants.dart`](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/my_flutter_app/lib/core/constants.dart) and paste:

```dart
static const String supabaseUrl = 'https://your-actual-project.supabase.co';
static const String supabaseAnonKey = 'eyJ...your-actual-anon-key...';
```

---

## Step 3: Run All Migrations

1. Go to your Supabase project → **SQL Editor**.
2. Run each migration file **in order**:
   - Paste and run: [`20260810000000_init_enums_and_functions.sql`](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/supabase/migrations/20260810000000_init_enums_and_functions.sql)
   - Paste and run: [`20260810000001_core_schema.sql`](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/supabase/migrations/20260810000001_core_schema.sql)
   - Paste and run: [`20260810000002_rls_policies.sql`](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/supabase/migrations/20260810000002_rls_policies.sql)
   - Paste and run: [`20260810000003_modules_schema.sql`](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/supabase/migrations/20260810000003_modules_schema.sql)
   - Paste and run: [`20260810000004_indexes_and_optimizations.sql`](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/supabase/migrations/20260810000004_indexes_and_optimizations.sql)
3. Run the verification script: [`verify_schema.sql`](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/scratch/verify_schema.sql)
   - You should see a list of `✅` messages and no `❌` warnings.

---

## Step 4: Deploy Edge Functions (via Supabase CLI)

If your machine's TLS certificates are valid (or from a CI/CD machine):

```bash
# Login to Supabase CLI
npx supabase login

# Link your project (get the project ref from Settings → General)
npx supabase link --project-ref your-project-ref

# Deploy functions
npx supabase functions deploy set-user-claims
npx supabase functions deploy invite-user
```

**Alternatively:** Copy the function code directly into the **Supabase Dashboard → Edge Functions → New Function** editor.

---

## Step 5: Configure Auth Hooks (JWT Custom Claims)

1. Go to **Authentication → Hooks** in your Supabase project.
2. Add a **"Custom Access Token"** hook:
   - **Function:** Select `set-user-claims`
3. This will inject `school_id`, `role`, and `profile_id` into every user's JWT automatically on login.

---

## Step 6: Create the First Super Admin

Run this SQL in the Supabase SQL Editor to create the platform's super admin:

```sql
-- Step 1: Create the auth user (replace with real email/password)
-- This is done via Dashboard → Authentication → Users → "Invite user"
-- Then run this to create their profile:

INSERT INTO public.schools (name, subdomain, status)
VALUES ('ZivoConnect Platform', 'platform', 'active')
RETURNING id;

-- Copy the returned school id and use it below:
INSERT INTO public.profiles (user_id, school_id, role, first_name, last_name, email, status)
VALUES (
  auth.uid(), -- Run this as the super admin user
  '<school_id_from_above>',
  'super_admin',
  'Platform',
  'Admin',
  'admin@zivoconnect.com',
  'active'
);
```

---

## Step 7: Run the Flutter App

```bash
cd my_flutter_app
flutter run
```

The app will connect to your Supabase Cloud project and you should see the **Login Screen**.

---

## Summary of Project Structure

```
School System/
├── supabase/
│   ├── config.toml                          # Local Supabase config (optional)
│   ├── migrations/                          # All 5 migration SQL files
│   │   ├── 20260810000000_init_enums_and_functions.sql
│   │   ├── 20260810000001_core_schema.sql
│   │   ├── 20260810000002_rls_policies.sql
│   │   ├── 20260810000003_modules_schema.sql
│   │   └── 20260810000004_indexes_and_optimizations.sql
│   └── functions/                           # Edge functions
│       ├── set-user-claims/index.ts         # JWT custom claims on login
│       └── invite-user/index.ts             # Super admin invite function
├── scratch/
│   └── verify_schema.sql                    # Schema validation script
├── my_flutter_app/
│   └── lib/
│       ├── main.dart                        # App entry point
│       ├── core/
│       │   ├── constants.dart               # Supabase keys + app config
│       │   └── theme.dart                   # Premium dark theme
│       ├── models/models.dart               # SchoolModel, ProfileModel, ActiveSession
│       ├── providers/providers.dart         # Riverpod providers
│       ├── services/services.dart           # AuthService, ProfileService, SchoolService
│       ├── router/router.dart               # go_router with auth guards
│       ├── widgets/shared_widgets.dart      # RoleBanner, ComingSoonGrid, ErrorCard
│       └── screens/
│           ├── auth/
│           │   ├── login_screen.dart        # Animated login UI
│           │   └── profile_picker_screen.dart # Multi-school profile selector
│           ├── super_admin/
│           │   └── super_admin_shell.dart   # Schools management + invite admin
│           ├── school_admin/
│           │   └── school_admin_shell.dart  # Users, classes, structure setup
│           ├── teacher/
│           │   └── teacher_shell.dart       # Teacher dashboard
│           ├── parent/
│           │   └── parent_shell.dart        # Cross-school parent dashboard
│           └── student/
│               └── student_shell.dart       # Student dashboard
├── implementation_plan.md
├── roadmap.md
├── task.md
└── walkthrough.md
```
