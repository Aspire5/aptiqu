import { ENV } from '../../../config/env';
import { log, safeError } from '../../../observability/logger';
import { readFile, readdir } from 'fs/promises';
import path from 'path';
import { prisma } from '../../../config/prisma';
import { roadmapProgressionService } from '../../roadmap/services/roadmap-progression.service';
import { scriptCacheService } from '../../lesson/services/script-cache.service';
import { AdminSyllabusService } from '../admin-syllabus.service';
import { catalogMutation } from '../../roadmap/services/catalog-mutation';
import { ScriptValidator } from '../../lesson/engines/script-validator';

const SUBJECT_NAME = 'RS Aggarwal - Quantitative Aptitude';
const SUBJECT_SLUG = 'rs-aggarwal-quantitative-aptitude';
const SUBTOPICS_DIR = ENV.CURRICULUM_SOURCE_ROOT;

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

export async function syncRsAggarwalOnStartup() {
  const counts = { topics: 0, subtopics: 0, scripts: 0, skippedScripts: 0, failedScripts: 0 };
  log('info','curriculum.sync.started');

  let folders;
  try {
    folders = (await readdir(SUBTOPICS_DIR, { withFileTypes: true }))
      .filter((entry) => entry.isDirectory() && /^SBT-RSA-\d+-/.test(entry.name))
      .sort((a, b) => Number(a.name.match(/^SBT-RSA-(\d+)-/)![1]) - Number(b.name.match(/^SBT-RSA-(\d+)-/)![1]));
  } catch (error: any) {
    log('warn','curriculum.source_unavailable',safeError(error));
    return { ...counts, sourceAvailable: false };
  }

  if (!folders.length) {
    log('warn','curriculum.source_empty');
    return { ...counts, sourceAvailable: false };
  }
  // A reset removes the subject too. Preserve existing and inactive subjects.
  let subject = await prisma.subject.findFirst({ where: { OR: [{ name: SUBJECT_NAME }, { slug: SUBJECT_SLUG }] } });
  if (!subject) subject = await prisma.subject.create({ data: {
    id: SUBJECT_SLUG, slug: SUBJECT_SLUG, name: SUBJECT_NAME, displayOrder: 1,
  } });
  if (!subject.isActive) {
    log('info','curriculum.subject_inactive');
    return { ...counts, sourceAvailable: true };
  }

  for (const folder of folders) {
    try {
      const chapter = Number(folder.name.match(/^SBT-RSA-(\d+)-/)![1]);
      const details = TOPICS[chapter] ?? {
        name: folder.name.replace(/^SBT-RSA-\d+-/, '').replace(/[_-]+/g, ' '),
        description: '',
      };

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
      } else if (topic.sequence !== sequence || (!topic.description && Boolean(details.description))) {
        topic = await prisma.topic.update({
          where: { id: topic.id },
          data: { sequence, ...(!topic.description ? { description: details.description } : {}) },
        });
      }
      if (!topic.isActive) {
        log('warn','rs_aggarwal_startup_sync_service.syncRsAggarwalOnStartup.warn');
        continue;
      }
      await prisma.subjectTopic.updateMany({
        where: { subjectId: subject.id, topicId: topic.id, sequence: { not: sequence } },
        data: { sequence },
      });

      const folderPath = path.join(SUBTOPICS_DIR, folder.name);
      let sourceSubtopics: SourceSubtopic[] | null = null;
      try {
        sourceSubtopics = JSON.parse(await readFile(path.join(folderPath, 'subtopics.json'), 'utf8'));
        if (!Array.isArray(sourceSubtopics) || sourceSubtopics.length === 0) {
          throw new Error('Expected a non-empty array.');
        }
      } catch (error: any) {
        sourceSubtopics = null;
        // Only the two legacy chapters may legitimately lack a manifest. A bad
        // approved manifest must never be silently replaced by inferred scope.
        if (chapter > 2 || error.code !== 'ENOENT') {
          counts.failedScripts++;
          log('warn','curriculum.manifest_unavailable',{...safeError(error),chapter});
          continue;
        }
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
            // One derived-roadmap reconciliation after the batch, not after every file.
            await catalogMutation(() => AdminSyllabusService.importSubtopics(topic.id, sourceSubtopics!, false), false);
            counts.subtopics += sourceSubtopics.length;
          }
        } catch (error: any) {
          counts.failedScripts++;
          log('error','curriculum.subtopics_failed',{ ...safeError(error), chapter });
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
        scriptFiles = (await readdir(scriptDir)).filter((name) => name.endsWith('.json') && !name.startsWith('_'))
          .sort((a,b) => a.localeCompare(b, 'en', { numeric: true }));
      } catch (error: any) {
        counts.failedScripts++;
        log('warn','curriculum.scripts_unavailable',{...safeError(error),chapter});
        continue;
      }

      // Where approved subtopics.json exists, import only its matching script files.
      if (sourceSubtopics) {
        const approvedKeys = new Set(sourceSubtopics.map((item) => item.externalSubTopicKey));
        for (const key of approvedKeys) {
          if (key && !scriptFiles.includes(`${key}.json`)) {
            counts.failedScripts++;
            log('warn','curriculum.script_missing',{chapter,script:`${key}.json`});
          }
        }
        scriptFiles = scriptFiles.filter((name) => approvedKeys.has(path.parse(name).name));
      }

      for (const fileName of scriptFiles) {
        try {
          const definition = JSON.parse(await readFile(path.join(scriptDir, fileName), 'utf8'));
          const normalized = scriptCacheService.normalizeScriptDefinition(definition);
          if (!ScriptValidator.validate(normalized).valid) {
            counts.failedScripts++;
            log('warn','curriculum.script_invalid',{chapter,script:fileName,code:'SCRIPT_GRAPH_INVALID'});
            continue;
          }
          const fileKey = path.parse(fileName).name;
          const scriptId = normalized.scriptId;
          if (typeof scriptId !== 'string' || !scriptId.trim()) {
            throw new Error('Missing scriptId.');
          }
          const candidateKey = scriptId.replace(/^script-/, '');
          let matches = subtopics.filter((item) =>
            item.id === fileKey || item.slug === fileKey ||
            item.id === candidateKey || item.slug === candidateKey ||
            normalizedName(item.name) === normalizedName(normalized.metadata?.title || '')
          );
          // Chapters 1/2 predate subtopics.json; use their saved script metadata.
          if (!matches.length && !sourceSubtopics && chapter <= 2) {
            const legacyId = typeof definition.subtopic?.id === 'string' ? definition.subtopic.id : candidateKey;
            const legacy = await prisma.subtopic.upsert({ where: { id: legacyId }, update: {}, create: {
              id: legacyId, slug: legacyId, topicId: topic.id,
              name: definition.subtopic?.name || normalized.metadata?.title || fileKey,
              description: normalized.metadata?.description || '', sequence: scriptFiles.indexOf(fileName),
            } });
            if (legacy.topicId !== topic.id) throw new Error('Legacy subtopic belongs to another topic.');
            subtopics.push(legacy);
            matches = [legacy];
            counts.subtopics++;
          }
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
          await catalogMutation(() => AdminSyllabusService.importScript({
            subjectId: subject.id,
            topicId: topic.id,
            subtopicId: subtopic.id,
            definition,
          }, false), false);
          counts.scripts++;
        } catch (error: any) {
          counts.failedScripts++;
          log('error','curriculum.script_failed',{ ...safeError(error), chapter, script: fileName });
        }
      }
    } catch (error: any) {
      counts.failedScripts++;
      log('error','curriculum.chapter_failed',{ ...safeError(error), chapter: Number(folder.name.match(/^SBT-RSA-(\d+)-/)![1]) });
    }
  }

  // Repair the graph even if a prior process stopped just after its last import.
  await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
  log(counts.failedScripts ? 'warn' : 'info','curriculum.sync.completed',counts);
  return { ...counts, sourceAvailable: true };
}
