-- 10. SOCIAL
-- ============================================================================
create table public.friendships (
  id             uuid primary key default gen_random_uuid(),
  requester_id   uuid not null references public.profiles(id) on delete cascade,
  addressee_id   uuid not null references public.profiles(id) on delete cascade,
  status         friend_request_status not null default 'pending',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (requester_id, addressee_id),
  constraint no_self_friend check (requester_id <> addressee_id)
);
create index idx_friendships_addressee on public.friendships (addressee_id, status);

create table public.blocks (
  id          uuid primary key default gen_random_uuid(),
  blocker_id  uuid not null references public.profiles(id) on delete cascade,
  blocked_id  uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (blocker_id, blocked_id),
  constraint no_self_block check (blocker_id <> blocked_id)
);

-- Public photo feed — the primary social feature. Visible to all app users
-- (not friends-only), single photo per post.
create table public.posts (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  image_url    text not null,
  caption      text,
  like_count   int not null default 0,      -- denormalized counter, kept in sync by trigger
  comment_count int not null default 0,     -- denormalized counter, kept in sync by trigger
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
create index idx_posts_feed on public.posts (created_at desc) where deleted_at is null;
create index idx_posts_user on public.posts (user_id, created_at desc) where deleted_at is null;

create table public.post_likes (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.posts(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (post_id, user_id)
);

create table public.post_comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.posts(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  content     text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index idx_post_comments_post on public.post_comments (post_id, created_at);

create table public.activities (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  activity_type   activity_type not null,
  reference_table text,
  reference_id    uuid,
  metadata        jsonb,
  created_at      timestamptz not null default now()
);
create index idx_activities_user_date on public.activities (user_id, created_at desc);

create table public.activity_comments (
  id           uuid primary key default gen_random_uuid(),
  activity_id  uuid not null references public.activities(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  content      text not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
create index idx_activity_comments_activity on public.activity_comments (activity_id, created_at);

create table public.notifications (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  type            notification_type not null,
  reference_table text,
  reference_id    uuid,
  message         text not null,
  is_read         boolean not null default false,
  created_at      timestamptz not null default now()
);
create index idx_notifications_user_unread on public.notifications (user_id, is_read, created_at desc);


-- ============================================================================
