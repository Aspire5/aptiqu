import { readFile, readdir } from 'fs/promises';
import path from 'path';
import { prisma } from '../../../config/prisma';
import { roadmapProgressionService } from '../../roadmap/services/roadmap-progression.service';
import { scriptCacheService } from '../../lesson/services/script-cache.service';
import { AdminSyllabusService } from '../admin-syllabus.service';

const SUBJECT_NAME = 'RS Aggarwal - Quantitative Aptitude';
const SUBTOPICS_DIR = path.resolve(__dirname, '../../../../../books/SubTopics');

// Topic descriptions are shown to students. Keep them short and useful.
const TOPICS: Record<number, { name: string; description: string }> = {
  1: { name: 'Number System', description: 'Build confidence with number types, place value, factors, divisibility, patterns, and number puzzles.' },
  2: { name: 'H.C.F. and L.C.M. of Numbers', description: 'Learn to find highest common factors and least common multiples, then use them to solve number problems.' },
  3: { name: 'Decimal Fractions', description: 'Read, compare, calculate with, and round decimals, then apply them to practical problems.' },
  4: { name: 'Simplification', description: 'Simplify numerical and algebraic expressions using the correct order of operations and useful identities.' },
  5: { name: 'Square Roots and Cube Roots', description: 'Recognize squares and cubes, calculate their roots, and simplify related expressions.' },
  6: { name: 'Average', description: 'Use totals, counts, and weighted averages to solve everyday and exam-style problems.' },
  7: { name: 'Problems on Numbers', description: 'Translate number relationships into equations and check which solutions satisfy the conditions.' },
  8: { name: 'Problems on Ages', description: 'Model past and future ages with equations, ratios, and clear timelines.' },
  9: { name: 'Surds and Indices', description: 'Work confidently with powers, roots, surds, and the rules that connect them.' },
  10: { name: 'Logarithms', description: 'Understand logarithms as exponents and use their laws to simplify and solve expressions.' },
  11: { name: 'Percentage', description: 'Convert percentages, compare quantities, and solve changes, rates, and application problems.' },
  12: { name: 'Profit and Loss', description: 'Calculate cost, selling price, profit, loss, discounts, and related commercial quantities.' },
  13: { name: 'Ratio and Proportion', description: 'Compare quantities, combine ratios, divide totals, and reason with proportional change.' },
  14: { name: 'Partnership', description: 'Share profit or loss fairly by comparing each partner’s capital and investment time.' },
};

type SourceSubtopic = {
  name: string;
  description?: string;
  priority?: string;
  externalSubTopicKey?: string;
  position?: number;
};

const normalizedName = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();

export async function syncRsAggarwalOnStartup(): Promise<void> {
  const subject = await prisma.subject.findFirst({ where: { name: SUBJECT_NAME, isActive: true } });
  if (!subject) {
    console.log('[RS Aggarwal sync] Subject is absent; skipping.');
    return;
  }

  let folders;
  try {
    folders = (await readdir(SUBTOPICS_DIR, { withFileTypes: true }))
      .filter((entry) => entry.isDirectory() && /^SBT-RSA-\d+-/.test(entry.name))
      .sort((a, b) => Number(a.name.match(/^SBT-RSA-(\d+)-/)![1]) - Number(b.name.match(/^SBT-RSA-(\d+)-/)![1]));
  } catch (error: any) {
    console.warn(`[RS Aggarwal sync] Cannot read ${SUBTOPICS_DIR}: ${error.message}`);
    return;
  }

  const counts = { topics: 0, subtopics: 0, scripts: 0, skippedScripts: 0, failedScripts: 0 };
  let changed = false;

  for (const folder of folders) {
    try {
      const chapter = Number(folder.name.match(/^SBT-RSA-(\d+)-/)![1]);
      const details = TOPICS[chapter];
      if (!details) {
        console.warn(`[RS Aggarwal sync] No student-facing topic metadata for ${folder.name}; skipping.`);
        continue;
      }

      const sequence = chapter - 1;
      const slug = `${subject.id}-${normalizedName(details.name).replace(/ /g, '-')}`;
      let topic = await prisma.topic.findFirst({
        where: { subjectId: subject.id, OR: [{ name: details.name }, { slug }] },
      });
      if (!topic) {
        topic = await prisma.topic.create({
          data: {
            id: slug,
            slug,
            subjectId: subject.id,
            name: details.name,
            description: details.description,
            sequence,
            defaultImportance: 'medium',
            defaultTeachingDepth: 3,
            defaultTeachingMinutes: 30,
            isActive: true,
          },
        });
        counts.topics++;
        changed = true;
      } else if (topic.sequence !== sequence || !topic.description) {
        topic = await prisma.topic.update({
          where: { id: topic.id },
          data: { sequence, ...(!topic.description ? { description: details.description } : {}) },
        });
        changed = true;
      }
      if (!topic.isActive) {
        console.warn(`[RS Aggarwal sync] Topic ${details.name} is inactive; leaving it untouched.`);
        continue;
      }
      const reorderedLinks = await prisma.subjectTopic.updateMany({
        where: { subjectId: subject.id, topicId: topic.id, sequence: { not: sequence } },
        data: { sequence },
      });
      if (reorderedLinks.count > 0) changed = true;

      const folderPath = path.join(SUBTOPICS_DIR, folder.name);
      let sourceSubtopics: SourceSubtopic[] | null = null;
      try {
        sourceSubtopics = JSON.parse(await readFile(path.join(folderPath, 'subtopics.json'), 'utf8'));
        if (!Array.isArray(sourceSubtopics) || sourceSubtopics.length === 0) {
          throw new Error('Expected a non-empty array.');
        }
      } catch (error: any) {
        sourceSubtopics = null;
        console.warn(`[RS Aggarwal sync] ${folder.name}/subtopics.json unavailable or invalid: ${error.message}`);
      }

      if (!sourceSubtopics && chapter > 2) continue;

      if (sourceSubtopics) {
        try {
          const current = await prisma.subtopic.findMany({ where: { topicId: topic.id } });
          const needsImport = sourceSubtopics.some((item, index) => {
            const key = item.externalSubTopicKey;
            const id = key || `${topic.id}-${item.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')}`;
            const stored = current.find((row) => row.id === id || (key && row.slug === key)) ||
              current.find((row) => row.name.trim().toLowerCase() === item.name.trim().toLowerCase());
            const priority = (item.priority || '').toLowerCase();
            return !stored || stored.slug !== (key || id) || stored.name !== item.name.trim() ||
              stored.description !== (item.description || '') ||
              stored.sequence !== (item.position ?? index) ||
              stored.importance !== (['high', 'medium', 'low'].includes(priority) ? priority : 'medium') ||
              !stored.isActive;
          });
          if (needsImport) {
            await AdminSyllabusService.importSubtopics(topic.id, sourceSubtopics, false);
            counts.subtopics += sourceSubtopics.length;
            changed = true;
          }
        } catch (error: any) {
          console.error(`[RS Aggarwal sync] Subtopics for ${details.name}: ${error.message}`);
          continue;
        }
      }

      const subtopics = await prisma.subtopic.findMany({
        where: { topicId: topic.id },
        select: { id: true, slug: true, name: true },
      });
      const scriptDir = path.join(folderPath, 'Scripts');
      let scriptFiles: string[];
      try {
        scriptFiles = (await readdir(scriptDir)).filter((name) => name.endsWith('.json') && !name.startsWith('_'));
      } catch (error: any) {
        console.warn(`[RS Aggarwal sync] Cannot read scripts for ${details.name}: ${error.message}`);
        continue;
      }

      // Where approved subtopics.json exists, import only its matching script files.
      if (sourceSubtopics) {
        const approvedKeys = new Set(sourceSubtopics.map((item) => item.externalSubTopicKey));
        for (const key of approvedKeys) {
          if (key && !scriptFiles.includes(`${key}.json`)) {
            console.warn(`[RS Aggarwal sync] Missing script for ${details.name} subtopic ${key}.`);
          }
        }
        scriptFiles = scriptFiles.filter((name) => approvedKeys.has(path.parse(name).name));
      }

      for (const fileName of scriptFiles) {
        try {
          const definition = JSON.parse(await readFile(path.join(scriptDir, fileName), 'utf8'));
          const normalized = scriptCacheService.normalizeScriptDefinition(definition);
          const fileKey = path.parse(fileName).name;
          const scriptId = normalized.scriptId;
          if (typeof scriptId !== 'string' || !scriptId.trim()) {
            throw new Error('Missing scriptId.');
          }
          const candidateKey = scriptId.replace(/^script-/, '');
          const matches = subtopics.filter((item) =>
            item.id === fileKey || item.slug === fileKey ||
            item.id === candidateKey || item.slug === candidateKey ||
            normalizedName(item.name) === normalizedName(normalized.metadata?.title || '')
          );
          if (matches.length !== 1) {
            throw new Error(`Expected one matching subtopic for ${fileName}; found ${matches.length}.`);
          }
          const subtopic = matches[0];
          const existing = await prisma.lessonScript.findUnique({
            where: { slug: scriptId },
            select: { topicId: true, subtopicId: true },
          });
          if (existing) {
            if (existing.topicId !== topic.id || existing.subtopicId !== subtopic.id) {
              throw new Error(`Script ID ${scriptId} is already attached to another topic or subtopic.`);
            }
            counts.skippedScripts++;
            continue;
          }
          const attached = await prisma.lessonScript.findFirst({
            where: { topicId: topic.id, subtopicId: subtopic.id },
            select: { slug: true },
          });
          if (attached) {
            counts.skippedScripts++;
            continue;
          }
          await AdminSyllabusService.importScript({
            subjectId: subject.id,
            topicId: topic.id,
            subtopicId: subtopic.id,
            definition,
          }, false);
          counts.scripts++;
          changed = true;
        } catch (error: any) {
          counts.failedScripts++;
          console.error(`[RS Aggarwal sync] ${folder.name}/Scripts/${fileName}: ${error.message}`);
        }
      }
    } catch (error: any) {
      console.error(`[RS Aggarwal sync] ${folder.name}: ${error.message}`);
    }
  }

  if (changed) await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
  console.log(`[RS Aggarwal sync] Created ${counts.topics} topics, processed ${counts.subtopics} subtopics, imported ${counts.scripts} scripts, skipped ${counts.skippedScripts} existing scripts, failed ${counts.failedScripts} scripts.`);
}
