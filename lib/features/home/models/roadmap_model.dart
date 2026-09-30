class RoadmapSubjectSummary {
  final String id;
  final String slug;
  final String name;
  final String? description;
  final int sequence;
  final int totalTopics;
  final int completedTopics;
  final int totalSubtopics;
  final int completedSubtopics;
  final int estimatedMinutes;
  final bool hasPlayableContent;
  final bool isStarted;
  final bool isCompleted;
  final String? activeStepId;

  RoadmapSubjectSummary({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.sequence,
    this.totalTopics = 0,
    this.completedTopics = 0,
    this.totalSubtopics = 0,
    this.completedSubtopics = 0,
    this.estimatedMinutes = 30,
    this.hasPlayableContent = false,
    this.isStarted = false,
    this.isCompleted = false,
    this.activeStepId,
  });

  double get progressPercentage {
    if (totalSubtopics > 0) {
      return (completedSubtopics / totalSubtopics).clamp(0.0, 1.0);
    }
    if (totalTopics > 0) {
      return (completedTopics / totalTopics).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  factory RoadmapSubjectSummary.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? progressMap}) {
    final prog = progressMap ?? (json['progress'] as Map<String, dynamic>? ?? {});
    return RoadmapSubjectSummary(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      sequence: json['sequence'] as int? ?? 1,
      totalTopics: prog['totalTopics'] as int? ?? 0,
      completedTopics: prog['completedTopics'] as int? ?? 0,
      totalSubtopics: prog['totalSubtopics'] as int? ?? 0,
      completedSubtopics: prog['completedSubtopics'] as int? ?? 0,
      estimatedMinutes: prog['estimatedMinutes'] as int? ?? 30,
      hasPlayableContent: prog['hasPlayableContent'] as bool? ?? false,
      isStarted: prog['isStarted'] as bool? ?? false,
      isCompleted: prog['isCompleted'] as bool? ?? false,
      activeStepId: prog['activeStepId'] as String?,
    );
  }
}

class ActiveRoadmapModel {
  final String id;
  final String slug;
  final String name;
  final String course;
  final String? description;
  final bool isDefault;
  final List<RoadmapSubjectSummary> subjects;

  ActiveRoadmapModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.course,
    this.description,
    this.isDefault = false,
    required this.subjects,
  });

  factory ActiveRoadmapModel.fromJson(Map<String, dynamic> json) {
    final rawSubjects = json['roadmapSubjects'] as List<dynamic>? ?? [];
    final subjects = rawSubjects.map((item) {
      final subjMap = item['subject'] as Map<String, dynamic>? ?? {};
      final progMap = item['progress'] as Map<String, dynamic>?;
      return RoadmapSubjectSummary.fromJson(
        {
          'id': subjMap['id'] as String? ?? item['subjectId'] as String,
          'slug': subjMap['slug'] as String? ?? subjMap['id'] as String? ?? '',
          'name': subjMap['name'] as String? ?? 'Subject',
          'description': subjMap['description'] as String?,
          'sequence': item['sequence'] as int? ?? 1,
        },
        progressMap: progMap,
      );
    }).toList();

    return ActiveRoadmapModel(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? json['id'] as String,
      name: json['name'] as String,
      course: json['course'] as String? ?? 'general',
      description: json['description'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      subjects: subjects,
    );
  }
}

class SubtopicItemModel {
  final String id;
  final String? scriptId;
  final String? scriptSlug;
  final String title;
  final int sequence;
  final bool isCompleted;
  final bool isLocked;
  final bool canReplay;

  SubtopicItemModel({
    required this.id,
    this.scriptId,
    this.scriptSlug,
    required this.title,
    required this.sequence,
    this.isCompleted = false,
    this.isLocked = true,
    this.canReplay = false,
  });

  factory SubtopicItemModel.fromJson(Map<String, dynamic> json) {
    return SubtopicItemModel(
      id: json['id'] as String? ?? '',
      scriptId: json['scriptId'] as String?,
      scriptSlug: json['scriptSlug'] as String?,
      title: json['title'] as String? ?? '',
      sequence: json['sequence'] as int? ?? 1,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? true,
      canReplay: json['canReplay'] as bool? ?? false,
    );
  }
}

class LearningMapTopicItemModel {
  final String roadmapStepId;
  final int sequence;
  final String topicId;
  final String topicName;
  final String topicSlug;
  final String? description;
  final String importance;
  final int teachingMinutes;
  final int teachingDepth;
  final String? subtopicId;
  final String? subtopicName;
  final String state; // 'LOCKED' | 'AVAILABLE' | 'IN_PROGRESS' | 'COMPLETED' | 'COMING_SOON'
  final bool scriptAvailable;
  final String? scriptSlug;
  final String? scriptTitle;
  final int totalSubtopics;
  final int completedSubtopics;
  final List<SubtopicItemModel> subtopics;

  LearningMapTopicItemModel({
    required this.roadmapStepId,
    required this.sequence,
    required this.topicId,
    required this.topicName,
    required this.topicSlug,
    this.description,
    required this.importance,
    required this.teachingMinutes,
    required this.teachingDepth,
    this.subtopicId,
    this.subtopicName,
    required this.state,
    required this.scriptAvailable,
    this.scriptSlug,
    this.scriptTitle,
    this.totalSubtopics = 0,
    this.completedSubtopics = 0,
    this.subtopics = const [],
  });

  bool get isCompleted => state == 'COMPLETED';
  bool get isInProgress => state == 'IN_PROGRESS';
  bool get isAvailable => state == 'AVAILABLE';
  bool get isLocked => state == 'LOCKED';
  bool get isComingSoon => state == 'COMING_SOON';

  factory LearningMapTopicItemModel.fromJson(Map<String, dynamic> json) {
    return LearningMapTopicItemModel(
      roadmapStepId: json['roadmapStepId'] as String,
      sequence: json['sequence'] as int? ?? 0,
      topicId: json['topicId'] as String,
      topicName: json['topicName'] as String,
      topicSlug: json['topicSlug'] as String? ?? json['topicId'] as String,
      description: json['description'] as String?,
      importance: json['importance'] as String? ?? 'medium',
      teachingMinutes: json['teachingMinutes'] as int? ?? 30,
      teachingDepth: json['teachingDepth'] as int? ?? 3,
      subtopicId: json['subtopicId'] as String?,
      subtopicName: json['subtopicName'] as String?,
      state: json['state'] as String? ?? 'COMING_SOON',
      scriptAvailable: json['scriptAvailable'] as bool? ?? false,
      scriptSlug: json['scriptSlug'] as String?,
      scriptTitle: json['scriptTitle'] as String?,
      totalSubtopics: json['totalSubtopics'] as int? ?? 0,
      completedSubtopics: json['completedSubtopics'] as int? ?? 0,
      subtopics: (json['subtopics'] as List<dynamic>?)
              ?.map((s) => SubtopicItemModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SubjectLearningMapModel {
  final String roadmapId;
  final String roadmapName;
  final String roadmapCourse;
  final String subjectId;
  final String subjectName;
  final String? subjectDescription;
  final List<LearningMapTopicItemModel> topics;
  final int totalTopics;
  final int completedTopics;
  final String? activeStepId;

  SubjectLearningMapModel({
    required this.roadmapId,
    required this.roadmapName,
    required this.roadmapCourse,
    required this.subjectId,
    required this.subjectName,
    this.subjectDescription,
    required this.topics,
    required this.totalTopics,
    required this.completedTopics,
    this.activeStepId,
  });

  factory SubjectLearningMapModel.fromJson(Map<String, dynamic> json) {
    final roadmap = json['roadmap'] as Map<String, dynamic>? ?? {};
    final subject = json['subject'] as Map<String, dynamic>? ?? {};
    final progress = json['progress'] as Map<String, dynamic>? ?? {};
    final rawTopics = json['topics'] as List<dynamic>? ?? [];

    final topicItems = rawTopics
        .map((t) => LearningMapTopicItemModel.fromJson(t as Map<String, dynamic>))
        .toList();

    return SubjectLearningMapModel(
      roadmapId: roadmap['id'] as String? ?? '',
      roadmapName: roadmap['name'] as String? ?? 'Curriculum',
      roadmapCourse: roadmap['course'] as String? ?? 'general',
      subjectId: subject['id'] as String? ?? '',
      subjectName: subject['name'] as String? ?? 'Subject',
      subjectDescription: subject['description'] as String?,
      topics: topicItems,
      totalTopics: progress['totalTopics'] as int? ?? topicItems.length,
      completedTopics: progress['completedTopics'] as int? ?? 0,
      activeStepId: progress['activeStepId'] as String?,
    );
  }
}
