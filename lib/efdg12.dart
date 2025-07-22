class EfDG12{
  final DateTime? dateOfIssue;
  final int fid;
  final String? issuingAuthority;
  final int sfi;
  final int tag;

  EfDG12({
    this.dateOfIssue,
    required this.fid,
    this.issuingAuthority,
    required this.sfi,
    required this.tag,
  });

  factory EfDG12.fromJson(Map<String, dynamic> json) {
    return EfDG12(
      dateOfIssue: json['dateOfIssue'] != null ? DateTime.parse(json['dateOfIssue']) : null,
      fid: json['fid'],
      issuingAuthority: json['issuingAuthority'],
      sfi: json['sfi'],
      tag: json['tag'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateOfIssue': dateOfIssue?.toIso8601String(),
      'fid': fid,
      'issuingAuthority': issuingAuthority,
      'sfi': sfi,
      'tag': tag,
    };
  }
}