import { prisma } from './prisma';
import { PublicError } from '../security/errors';
export async function getPracticeTiming(){
  return await prisma.practiceTimingPolicy.findUnique({where:{id:'practice'}})??{id:'practice',minSeconds:30,maxSeconds:120,version:0};
}
export async function updatePracticeTiming(input:{practiceMin?:number;practiceMax?:number;expectedVersion?:number}){
  return prisma.$transaction(async tx=>{
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('aptiqu:practice-timing'))`;
    const current=await tx.practiceTimingPolicy.findUnique({where:{id:'practice'}})??{minSeconds:30,maxSeconds:120,version:0};
    if(input.expectedVersion!==current.version)throw new PublicError('Timing policy changed. Read its version before editing.','VERSION_CONFLICT',409);
    const minSeconds=input.practiceMin??current.minSeconds,maxSeconds=input.practiceMax??current.maxSeconds;
    if(!Number.isInteger(minSeconds)||!Number.isInteger(maxSeconds)||minSeconds<30||maxSeconds>120||minSeconds>maxSeconds)throw new PublicError('Invalid practice timing bounds');
    return tx.practiceTimingPolicy.upsert({where:{id:'practice'},create:{id:'practice',minSeconds,maxSeconds,version:1},update:{minSeconds,maxSeconds,version:{increment:1}}});
  });
}
