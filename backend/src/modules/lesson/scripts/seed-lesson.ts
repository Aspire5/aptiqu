import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { prisma } from '../../../config/prisma';
import { ScriptValidator } from '../engines/script-validator';
import { ScriptDefinition } from '../interfaces/script-dsl.interface';

export async function publishScriptFromJson(filePath: string) {
  const resolvedPath = path.resolve(filePath);
  if (!fs.existsSync(resolvedPath)) {
    throw new Error(`Script file not found at: ${resolvedPath}`);
  }

  const rawJson = fs.readFileSync(resolvedPath, 'utf8');
  const parsed = JSON.parse(rawJson);
  const definitions: ScriptDefinition[] = Array.isArray(parsed) ? parsed : [parsed];

  const publishedScripts: any[] = [];

  for (const definition of definitions) {
    // 1. Validate script DSL
    const validation = ScriptValidator.validate(definition);
    if (!validation.valid) {
      console.error(`❌ Script "${definition.scriptId}" validation failed:`);
      for (const err of validation.errors) {
        console.error(` - [${err.field}]: ${err.message}`);
      }
      process.exit(1);
    }

    console.log(`✅ Script "${definition.scriptId}" validated successfully!`);

    const checksum = crypto.createHash('sha256').update(JSON.stringify(definition)).digest('hex');

    // 2. Find or create lesson script
    let script = await prisma.lessonScript.findUnique({
      where: { slug: definition.scriptId },
    });

    if (!script) {
      script = await prisma.lessonScript.create({
        data: {
          slug: definition.scriptId,
          title: definition.metadata.title,
          subjectId: definition.metadata.subjectId,
          topicId: definition.metadata.topicId,
          subtopicId: definition.metadata.subtopicId,
          status: 'PUBLISHED',
        },
      });
    } else {
      script = await prisma.lessonScript.update({
        where: { id: script.id },
        data: {
          title: definition.metadata.title,
          subjectId: definition.metadata.subjectId,
          topicId: definition.metadata.topicId,
          subtopicId: definition.metadata.subtopicId,
          status: 'PUBLISHED',
        },
      });
    }

    // 3. Create script version
    const versionRow = await prisma.lessonScriptVersion.upsert({
      where: {
        scriptId_versionNumber: {
          scriptId: script.id,
          versionNumber: definition.version,
        },
      },
      update: {
        definition: definition as any,
        checksum,
        schemaVersion: definition.schemaVersion,
        status: 'PUBLISHED',
        publishedAt: new Date(),
      },
      create: {
        scriptId: script.id,
        versionNumber: definition.version,
        schemaVersion: definition.schemaVersion,
        definition: definition as any,
        checksum,
        status: 'PUBLISHED',
        publishedAt: new Date(),
      },
    });

    // 4. Update publishedVersionId pointer on script
    const updatedScript = await prisma.lessonScript.update({
      where: { id: script.id },
      data: {
        publishedVersionId: versionRow.id,
        status: 'PUBLISHED',
      },
    });

    console.log(`🚀 Published script "${definition.scriptId}" (v${definition.version}) with ID: ${versionRow.id}`);
    publishedScripts.push(updatedScript);
  }

  return publishedScripts;
}

// Auto-run if executed from CLI
if (require.main === module) {
  const targetFile = process.argv[2];
  if (!targetFile) {
    console.log('Usage: npx tsx src/modules/lesson/scripts/seed-lesson.ts <path-to-script.json>');
    process.exit(1);
  }
  publishScriptFromJson(targetFile)
    .catch((err) => {
      console.error('Failed to seed script:', err);
      process.exit(1);
    })
    .finally(() => prisma.$disconnect());
}
