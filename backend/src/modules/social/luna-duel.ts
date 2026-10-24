import { Prisma, Question } from '@prisma/client';
import { socialError } from './social.transport';

/** Called inside preparation publication, with both user locks and the preparation row held. */
export async function finalizePreparedDuel(tx:Prisma.TransactionClient,id:string,questions:Question[],snapshot:Prisma.InputJsonValue,now:Date){
  const duel=await tx.friendlyDuel.findUnique({where:{id}});
  if(!duel||duel.status!=='PREPARING'||duel.expiresAt<=now)throw socialError('This duel preparation expired.',409);
  const friendship=await tx.friendship.findUnique({where:{id:duel.friendshipId}});
  if(friendship?.status!=='ACCEPTED'||await tx.friendlyDuelSeat.count({where:{duelId:id}})!==2)throw socialError('This duel is no longer available.',409);
  await tx.friendlyDuel.update({where:{id},data:{status:'ACTIVE',questionSnapshot:snapshot,matchExpiresAt:new Date(+now+86400000)}});
  for(const userId of [duel.requesterId,duel.recipientId]){
    const session=await tx.practiceSession.create({data:{userId,friendlyDuelId:id,isFriendlyDuel:true,timerEnabled:duel.timerEnabled,
      subjectId:questions[0].subjectId,topicId:questions[0].topicId,subtopicIds:duel.subtopicIds,totalQuestions:10,questionSnapshot:snapshot}});
    await tx.practiceSessionQuestion.createMany({data:questions.map((q,i)=>({sessionId:session.id,questionId:q.id,sequence:i+1}))});
  }
}
