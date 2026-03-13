
import 'package:mosl_network/network/models/json_message_response.dart' show JsonMessageResponse;

class StoryBannerModel  extends JsonMessageResponse{
  int? statusCode;
  List<Data>? data;

  StoryBannerModel({this.statusCode, this.data});


  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    json['data'].forEach((v) {
      data?.add(Data.fromJson(v));
    });
  }

  @override
  Map<String, dynamic> get toJson {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['statusCode'] = statusCode;
    if (this.data != null) {
      data['data'] = this.data!.map((Data v) => v.toJson()).toList();
    }
    return data;
  }

  factory StoryBannerModel.initial() {
    return StoryBannerModel(
        data: []
    );
  }
}

class Data {
  int? storyId;
  String? title;
  String? shortDescription;
  String? longDescription;
  String? imageUrl;
  int? sequence;
  bool? isActive;
  String? startDate;
  String? endDate;
  String? redirectionType;
  String? redirectionLink;
  String? contentPlacement;
  String? sourceApplication;
  String? mapToAssets;
  String? eventName;
  String? eventParameter;
  String? eventParameterValue;

  String? access;
  bool? isNewVisible;

  Data(
      {this.storyId,
        this.title,
        this.shortDescription,
        this.longDescription,
        this.imageUrl,
        this.sequence,
        this.isActive,
        this.startDate,
        this.endDate,
        this.redirectionType,
        this.redirectionLink,
        this.contentPlacement,
        this.sourceApplication,
        this.mapToAssets,
        this.eventName,
        this.eventParameter,
        this.eventParameterValue,this.access, this.isNewVisible});

  Data.fromJson(Map<String, dynamic> json) {
    storyId = json['storyId'];
    title = json['title'];
    shortDescription = json['shortDescription'];
    longDescription = json['longDescription'];
    imageUrl = json['imageUrl'];
    sequence = json['sequence'];
    isActive = json['isActive'];
    startDate = json['startDate'];
    endDate = json['endDate'];
    redirectionType = json['redirectionType'];
    redirectionLink = json['redirectionLink'];
    contentPlacement = json['contentPlacement'];
    sourceApplication = json['sourceApplication'];
    mapToAssets = json['mapToAssets'];
    eventName = json['eventName'];
    eventParameter = json['eventParameter'];
    eventParameterValue = json['eventParameterValue'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['storyId'] = storyId;
    data['title'] = title;
    data['shortDescription'] = shortDescription;
    data['longDescription'] = longDescription;
    data['imageUrl'] = imageUrl;
    data['sequence'] = sequence;
    data['isActive'] = isActive;
    data['startDate'] = startDate;
    data['endDate'] = endDate;
    data['redirectionType'] = redirectionType;
    data['redirectionLink'] = redirectionLink;
    data['contentPlacement'] = contentPlacement;
    data['sourceApplication'] = sourceApplication;
    data['mapToAssets'] = mapToAssets;
    data['eventName'] = eventName;
    data['eventParameter'] = eventParameter;
    data['eventParameterValue'] = eventParameterValue;
    return data;
  }
}