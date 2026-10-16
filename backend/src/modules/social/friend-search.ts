import { Prisma } from '@prisma/client';

// Literal matching, not SQL wildcard input. Rank exact, prefix, then substring
// matches in SQL so the limit applies to the best results, not an arbitrary page.
export function friendSearchQuery(user: string, query: string) {
  const escaped = query.replace(/[\\%_]/g, '\\$&');
  const prefix = `${escaped}%`, contains = `%${escaped}%`;
  return Prisma.sql`
    SELECT u.id FROM auth.users u
    JOIN users.profiles p ON p.user_id = u.id
    WHERE u.id <> ${user}::uuid AND u.is_registration_complete
      AND (p.search_name LIKE ${contains} OR lower(u.email) LIKE ${contains})
    ORDER BY CASE
      WHEN p.search_name = ${query} OR lower(u.email) = ${query} THEN 0
      WHEN p.search_name LIKE ${prefix} OR lower(u.email) LIKE ${prefix} THEN 1
      ELSE 2 END,
      LEAST(CASE WHEN position(${query} in p.search_name) > 0 THEN position(${query} in p.search_name) ELSE 100000 END,
        CASE WHEN position(${query} in lower(u.email)) > 0 THEN position(${query} in lower(u.email)) ELSE 100000 END),
      p.search_name, u.id
    LIMIT 10`;
}
