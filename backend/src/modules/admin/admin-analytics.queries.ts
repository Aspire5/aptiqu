import { Prisma } from '@prisma/client';
import { dateKey } from '../home/home.metrics';
export function periods(now=new Date()) {
  const today=dateKey(now),midnight=new Date(`${today}T00:00:00+05:30`);
  const result:Array<{kind:string;position:number;date:string;label:string;start:string;finish:string}>=[];
  const add=(kind:string,position:number,start:Date,finish:Date,label:string)=>result.push({kind,position,date:dateKey(start),label,start:start.toISOString(),finish:finish.toISOString()});
  for(let i=6;i>=0;i--){const start=new Date(+midnight-i*86400000);add('daily',6-i,start,new Date(+start+86400000),start.toLocaleDateString('en-US',{timeZone:'Asia/Kolkata',weekday:'short',month:'numeric',day:'numeric'}));}
  for(let i=3;i>=0;i--){const finish=new Date(+midnight+86400000-i*7*86400000);add('weekly',3-i,new Date(+finish-7*86400000),finish,`Week ${4-i}`);}
  const [year,month]=today.split('-').map(Number);
  for(let i=11;i>=0;i--){const first=new Date(Date.UTC(year,month-1-i,1)-19800000),next=new Date(Date.UTC(year,month-i,1)-19800000);add('monthly',11-i,first,next,first.toLocaleDateString('en-US',{timeZone:'Asia/Kolkata',month:'short',year:'2-digit'}));}
  return result;
}
export function growthQuery(now=new Date()) {
  return Prisma.sql`WITH buckets AS (SELECT * FROM jsonb_to_recordset(${JSON.stringify(periods(now))}::jsonb) AS b(kind text,position int,date text,label text,start timestamptz,finish timestamptz)),
    events AS (
      SELECT id AS user_id,created_at AS at FROM auth.users UNION ALL SELECT id,updated_at FROM auth.users
      UNION ALL SELECT user_id,started_at FROM learning.lesson_sessions UNION ALL SELECT user_id,created_at FROM learning.practice_sessions
      UNION ALL SELECT user_id,started_at FROM learning.daily_challenge_participations UNION ALL SELECT user_id,joined_at FROM learning.pvp_match_players
    ), registered AS (
      SELECT b.kind,b.position,count(u.id)::int AS registered FROM buckets b LEFT JOIN auth.users u ON u.created_at >= b.start AT TIME ZONE 'UTC' AND u.created_at < b.finish AT TIME ZONE 'UTC' GROUP BY b.kind,b.position
    ), active AS (
      SELECT b.kind,b.position,count(DISTINCT e.user_id)::int AS active FROM buckets b LEFT JOIN events e ON e.at >= b.start AT TIME ZONE 'UTC' AND e.at < b.finish AT TIME ZONE 'UTC' GROUP BY b.kind,b.position
    ) SELECT b.kind,b.position,b.label,b.date,r.registered,a.active FROM buckets b JOIN registered r USING(kind,position) JOIN active a USING(kind,position) ORDER BY kind,position`;
}
export function activityQuery(now=new Date()) {
  return Prisma.sql`WITH buckets AS (SELECT * FROM jsonb_to_recordset(${JSON.stringify(periods(now).filter(p=>p.kind==='daily'))}::jsonb) AS b(kind text,position int,date text,label text,start timestamptz,finish timestamptz)),events AS (
    SELECT created_at AS at,'pvp' AS source FROM learning.pvp_matches
    UNION ALL SELECT created_at,'practice' FROM learning.practice_sessions
    UNION ALL SELECT created_at,'replays' FROM learning.practice_sessions WHERE is_replay
    UNION ALL SELECT started_at,'scripts' FROM learning.lesson_sessions WHERE status='COMPLETED'
  ) SELECT b.date,b.label,count(*) FILTER(WHERE e.source='pvp')::int AS pvp,count(*) FILTER(WHERE e.source='practice')::int AS practice,
      count(*) FILTER(WHERE e.source='scripts')::int AS scripts,count(*) FILTER(WHERE e.source='replays')::int AS replays
    FROM buckets b LEFT JOIN events e ON e.at >= b.start AT TIME ZONE 'UTC' AND e.at < b.finish AT TIME ZONE 'UTC'
    GROUP BY b.position,b.date,b.label ORDER BY b.position`;
}
