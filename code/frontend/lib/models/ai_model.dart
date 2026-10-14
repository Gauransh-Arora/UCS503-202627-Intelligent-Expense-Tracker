class NLQueryResponseModel {
  final String question;
  final String answer;
  final String? queryType;
  final dynamic data;

  const NLQueryResponseModel({
    required this.question,
    required this.answer,
    this.queryType,
    this.data,
  });

  factory NLQueryResponseModel.fromJson(Map<String, dynamic> json) {
    return NLQueryResponseModel(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? 'No response available.',
      queryType: json['query_type'] as String?,
      data: json['data'],
    );
  }
}
