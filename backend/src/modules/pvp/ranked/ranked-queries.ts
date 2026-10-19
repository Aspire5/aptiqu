import { Prisma } from '@prisma/client';
import { BoardCursor } from './ranked-cursor';

/** One page and all its ordinals share one DB snapshot. Counts refer to the
 * complete eligible board, never to a previous cursor's old ordinal. */
export function leaderboardQuery(seasonId: string, limit: number, finalized: boolean, cursor?: BoardCursor) {
  const rating = finalized ? Prisma.sql`p.final_rating` : Prisma.sql`p.rating`;
  const eligible = finalized ? Prisma.sql`p.final_position IS NOT NULL` : Prisma.sql`p.qualified_at IS NOT NULL`;
  const after = cursor ? Prisma.sql`AND (${rating}<${cursor.rating} OR (${rating}=${cursor.rating} AND p.user_id>${cursor.userId}::uuid))` : Prisma.empty;
  const position = finalized ? Prisma.sql`page.final_position` : Prisma.sql`(SELECT (1+count(*))::integer FROM learning.ranked_player_seasons ahead
    WHERE ahead.season_id=${seasonId} AND ahead.qualified_at IS NOT NULL
    AND (ahead.rating>page.rating OR (ahead.rating=page.rating AND ahead.user_id<page.user_id)))`;
  return Prisma.sql`WITH page AS (
    SELECT p.user_id, ${rating} AS rating, p.final_position
    FROM learning.ranked_player_seasons p WHERE p.season_id=${seasonId} AND ${eligible} ${after}
    ORDER BY ${rating} DESC,p.user_id ASC LIMIT ${limit + 1}
  ) SELECT page.user_id AS "userId",page.rating,${position} AS position,
    profile.first_name AS "firstName",profile.last_name AS "lastName",profile.avatar_url AS "avatarUrl"
    FROM page LEFT JOIN users.profiles profile ON profile.user_id=page.user_id
    ORDER BY page.rating DESC,page.user_id ASC`;
}
