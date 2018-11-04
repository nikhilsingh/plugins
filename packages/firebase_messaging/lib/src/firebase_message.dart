
class FirebaseMessage
{
  final bool isBackgroundMessage;
  final Map<String, dynamic> data;

  FirebaseMessage(this.isBackgroundMessage, this.data);

  @override
  String toString() => '($data)';
}