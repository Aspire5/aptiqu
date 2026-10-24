import { resolveScope } from '../ai/luna/references';

export async function resolveDuelScope(requested: string[]) {
  return (await resolveScope({subtopicIds:requested.length?requested:undefined})).subtopicIds;
}
