import 'package:flutter_test/flutter_test.dart';
import 'package:mosl_network/network/models/fund_details_model.dart';
import 'package:mosl_network/network/models/story_banner_model.dart';

// ---------------------------------------------------------------------------
// Minimal valid FundDatum JSON payload (all required fields)
// ---------------------------------------------------------------------------
Map<String, dynamic> _fundDatumJson({
  String? schemeName,
  String? isinCode,
  String? inceptionDate,
}) =>
    {
      'investor_double_month': 6,
      'scheme_name': schemeName ?? 'Test Scheme',
      'tax_implication_text': 'LTCG',
      'description': 'Some description',
      'isin_code': isinCode ?? 'INF123',
      'min_initial_investment': 500.0,
      'amc_logo': 'https://example.com/logo.png',
      'min_exit_load_duration': 12,
      'benchmark_name': 'Nifty 50',
      'bmkret_3mnth_g': 1.1,
      'bmkret_6mnth_g': 2.2,
      'bmkret_1yr_g': 3.3,
      'bmkret_3yr_g': 4.4,
      'bmkret_5yr_g': 5.5,
      'bmkret_since_inceptn_g': 6.6,
      'bmkret_3mnth_d': 0.1,
      'bmkret_6mnth_d': 0.2,
      'bmkret_1yr_d': 0.3,
      'bmkret_3yr_d': 0.4,
      'bmkret_5yr_d': 0.5,
      'bmkret_since_inceptn_d': 0.6,
      'fd_rate_3month': '3.5',
      'fd_rate_6month': '4.0',
      'fd_rate_1year': '6.0',
      'fd_rate_3year': '7.0',
      'fd_rate_5year': '7.5',
      'fd_rate_max': '8.0',
      'latest_nav': 120.5,
      'sipminimuminstallmentamount': 500.0,
      'minpuramt': 1000.0,
      'min_subsequent_investment': 500.0,
      'stamp_duty': 0.005,
      'is_dividend': false,
      'amc_start_date': inceptionDate ?? '2010-01-01',
      'inception_date': inceptionDate ?? '2010-01-01',
      'stamp_duty_date': '2020-06-01',
      'start_date': '2010-01-01',
      'nfo_start_date': '2010-01-01',
      'nfo_end_date': '2010-01-31',
      'nav_date': '2024-01-01',
      'sub_category': 'Large Cap',
      'category': 'Equity',
      'fund_aum': 5000.0,
      'amc_aum': 10000.0,
      'address1': 'Addr1',
      'address2': 'Addr2',
      'address3': 'Addr3',
      'amc_full_name': 'Test AMC Full',
      'amc_short_name': 'TAMC',
      'phone': '1234567890',
      'amc_aum_as_on_date': '2024-01-01',
      'risk_level': 'Moderate',
      'expense_ratio_inclusive_gst': 1.25,
      'equitypercentage': 70.0,
      'exit_load': 1.0,
      'rank_1month': 5,
      'rank_3month': 3,
      'rank_6month': 2,
      'rank_1year': 1,
      'rank_3year': 1,
      'rank_5year': 2,
      'rank_10year': 3,
      'ret_1month': 0.5,
      'ret_3month': 1.5,
      'ret_6month': 3.0,
      'ret_1year': 12.0,
      'ret_3year': 36.0,
      'ret_5year': 60.0,
      'ret_10year': 120.0,
      'sip_ret_since_inception': 15.0,
      'sip_ret_3month': 1.0,
      'sip_ret_6month': 2.0,
      'sip_ret_1year': 10.0,
      'sip_ret_3year': 30.0,
      'sip_ret_5year': 50.0,
      'sip_ret_10year': 100.0,
      'annualized_returns': 14.5,
      'ratings': '4',
      'fund_managers': 'John Doe',
      'load_note': 'No load',
      'sipflag': 'Y',
      'purallowed': 'Y',
      'large_percentage': 60.0,
      'small_percentage': 10.0,
      'mid_percentage': 30.0,
      'is_new_fund': false,
      'simpl_ret_1year': '12.0',
      'simpl_ret_3year': '36.0',
      'simpl_ret_5year': '60.0',
      'simpl_ret_10year': '120.0',
      'sipmaximuminstallmentamount': 50000.0,
      'maxpuramtmul': 100000.0,
      'reopeningdate': '2025-01-01',
    };

void main() {
  group('FundDatum', () {
    test('fromJson parses all standard fields correctly', () {
      final datum = FundDatum.fromJson(_fundDatumJson());

      expect(datum.schemeName, 'Test Scheme');
      expect(datum.isinCode, 'INF123');
      expect(datum.investorDoubleMonth, 6);
      expect(datum.minInitialInvestment, 500.0);
      expect(datum.amcLogo, 'https://example.com/logo.png');
      expect(datum.benchmark3Month, 1.1);
      expect(datum.FD3Month, 3.5);
      expect(datum.FD1Yr, 6.0);
      expect(datum.nav, 120.5);
      expect(datum.sipMinAmount, 500.0);
      expect(datum.isDividend, isFalse);
      expect(datum.inceptionDate, DateTime.parse('2010-01-01'));
      expect(datum.ratings, '4');
      expect(datum.fundManagers, 'John Doe');
      expect(datum.sipFlag, 'Y');
      expect(datum.LumFlag, 'Y');
      expect(datum.largePerc, 60.0);
      expect(datum.isNFO, isFalse);
      expect(datum.simplRet1year, 12.0);
      expect(datum.maxAmount, 50000.0);
      expect(datum.MaxLumAmount, 100000.0);
    });

    test('fromJson uses defaults when fields are null', () {
      final minimal = <String, dynamic>{
        'investor_double_month': null,
        'scheme_name': null,
        'tax_implication_text': null,
        'description': null,
        'isin_code': null,
        'min_initial_investment': null,
        'amc_logo': null,
        'min_exit_load_duration': null,
        'benchmark_name': null,
        'bmkret_3mnth_g': null,
        'bmkret_6mnth_g': null,
        'bmkret_1yr_g': null,
        'bmkret_3yr_g': null,
        'bmkret_5yr_g': null,
        'bmkret_since_inceptn_g': null,
        'bmkret_3mnth_d': null,
        'bmkret_6mnth_d': null,
        'bmkret_1yr_d': null,
        'bmkret_3yr_d': null,
        'bmkret_5yr_d': null,
        'bmkret_since_inceptn_d': null,
        'fd_rate_3month': null,
        'fd_rate_6month': null,
        'fd_rate_1year': null,
        'fd_rate_3year': null,
        'fd_rate_5year': null,
        'fd_rate_max': null,
        'latest_nav': null,
        'sipminimuminstallmentamount': null,
        'minpuramt': null,
        'min_subsequent_investment': null,
        'stamp_duty': null,
        'is_dividend': null,
        'amc_start_date': null,
        'inception_date': null,
        'stamp_duty_date': null,
        'start_date': null,
        'nfo_start_date': null,
        'nfo_end_date': null,
        'nav_date': null,
        'sub_category': null,
        'category': null,
        'fund_aum': null,
        'amc_aum': null,
        'address1': null,
        'address2': null,
        'address3': null,
        'amc_full_name': null,
        'amc_short_name': null,
        'phone': null,
        'amc_aum_as_on_date': null,
        'risk_level': null,
        'expense_ratio_inclusive_gst': null,
        'equitypercentage': null,
        'exit_load': null,
        'rank_1month': null,
        'rank_3month': null,
        'rank_6month': null,
        'rank_1year': null,
        'rank_3year': null,
        'rank_5year': null,
        'rank_10year': null,
        'ret_1month': null,
        'ret_3month': null,
        'ret_6month': null,
        'ret_1year': null,
        'ret_3year': null,
        'ret_5year': null,
        'ret_10year': null,
        'sip_ret_since_inception': null,
        'sip_ret_3month': null,
        'sip_ret_6month': null,
        'sip_ret_1year': null,
        'sip_ret_3year': null,
        'sip_ret_5year': null,
        'sip_ret_10year': null,
        'annualized_returns': null,
        'ratings': null,
        'fund_managers': null,
        'load_note': null,
        'sipflag': null,
        'purallowed': null,
        'large_percentage': null,
        'small_percentage': null,
        'mid_percentage': null,
        'is_new_fund': null,
        'simpl_ret_1year': null,
        'simpl_ret_3year': null,
        'simpl_ret_5year': null,
        'simpl_ret_10year': null,
        'sipmaximuminstallmentamount': null,
        'maxpuramtmul': null,
        'reopeningdate': null,
      };

      final datum = FundDatum.fromJson(minimal);

      expect(datum.schemeName, '');
      expect(datum.isinCode, '');
      expect(datum.investorDoubleMonth, 0);
      expect(datum.minInitialInvestment, 0.0);
      expect(datum.benchmark3Month, 0.0);
      expect(datum.FD3Month, 0.0);
      expect(datum.nav, 0.0);
      expect(datum.isDividend, isFalse);
      expect(datum.isNFO, isFalse);
      expect(datum.simplRet1year, 0.0);
      expect(datum.rank1Month, 0);
    });

    test('_parseDate returns DateTime.now() for invalid or empty date', () {
      // Empty string → falls back to DateTime.now()
      final datumEmpty = FundDatum.fromJson({..._fundDatumJson(), 'inception_date': ''});
      expect(datumEmpty.inceptionDate.difference(DateTime.now()).abs().inSeconds, lessThan(5));

      // Unparsable string → falls back too
      final datumBad = FundDatum.fromJson({..._fundDatumJson(), 'inception_date': 'not-a-date'});
      expect(datumBad.inceptionDate.difference(DateTime.now()).abs().inSeconds, lessThan(5));
    });

    test('toJson round-trips key fields', () {
      final datum = FundDatum.fromJson(_fundDatumJson());
      final json = datum.toJson();

      expect(json['scheme_name'], 'Test Scheme');
      expect(json['isin_code'], 'INF123');
      expect(json['is_dividend'], isFalse);
      expect(json['sipflag'], 'Y');
      expect(json['bmkret_3mnth_g'], 1.1);
      expect(json['annualized_returns'], 14.5);
    });
  });

  group('SchemeDetailsModel', () {
    test('fromJson populates data list correctly', () {
      final model = SchemeDetailsModel.initial();
      model.fromJson({
        'status': true,
        'message': 'ok',
        'data': [_fundDatumJson(schemeName: 'Fund A'), _fundDatumJson(schemeName: 'Fund B')],
      });

      expect(model.status, isTrue);
      expect(model.message, 'ok');
      expect(model.data.length, 2);
      expect(model.data.first.schemeName, 'Fund A');
      expect(model.data.last.schemeName, 'Fund B');
    });

    test('toJson produces non-empty list from populated model', () {
      final model = SchemeDetailsModel.initial();
      model.fromJson({
        'status': true,
        'message': 'ok',
        'data': [_fundDatumJson()],
      });

      final json = model.toJson;
      expect((json['data'] as List).length, 1);
    });

    test('requestJson includes all expected keys', () {
      final json = SchemeDetailsModel.requestJson('myId');
      expect(json['id'], 'myId');
      expect(json['currentPageNumber'], 1);
      expect(json['pageSize'], 3);
      expect(json['type'], 'trans_vr_fund_details');
      expect(json['fromdate'], '');
      expect(json['todate'], '');
    });
  });

  group('MarketCapData', () {
    test('fromJson and toJson round-trip correctly', () {
      final json = {
        'marketcap_name': 'Large Cap',
        'marketcap_assetvalue': 5000.0,
        'marketcap_assetperc': 60.0,
      };
      final data = MarketCapData.fromJson(json);

      expect(data.marketcapName, 'Large Cap');
      expect(data.marketcapAssetvalue, 5000.0);
      expect(data.marketcapAssetperc, 60.0);

      final out = data.toJson();
      expect(out['marketcap_name'], 'Large Cap');
      expect(out['marketcap_assetvalue'], 5000.0);
    });

    test('marketCapDataFromJson parses a list from JSON string', () {
      const str =
          '[{"marketcap_name":"Large","marketcap_assetvalue":1.0,"marketcap_assetperc":50.0}]';
      final list = marketCapDataFromJson(str);

      expect(list.length, 1);
      expect(list.first.marketcapName, 'Large');
    });

    test('marketCapDataToJson encodes list to JSON string', () {
      final list = [
        MarketCapData(marketcapName: 'Mid', marketcapAssetvalue: 200.0, marketcapAssetperc: 30.0),
      ];
      final str = marketCapDataToJson(list);
      expect(str, contains('Mid'));
    });
  });

  group('FundManagerData', () {
    test('fromJson and toJson round-trip', () {
      final json = {'name': 'Alice', 'education': 'MBA', 'experience': '10 years'};
      final mgr = FundManagerData.fromJson(json);

      expect(mgr.name, 'Alice');
      expect(mgr.education, 'MBA');
      expect(mgr.experience, '10 years');

      final out = mgr.toJson();
      expect(out['name'], 'Alice');
    });

    test('fromJson uses empty string defaults for missing optional fields', () {
      final mgr = FundManagerData.fromJson({'name': 'Bob'});
      expect(mgr.education, '');
      expect(mgr.experience, '');
    });

    test('fundManagerDataFromJson and toJson handle a list', () {
      const str = '[{"name":"Eve","education":"PhD","experience":"5y"}]';
      final list = fundManagerDataFromJson(str);
      expect(list.first.name, 'Eve');

      final encoded = fundManagerDataToJson(list);
      expect(encoded, contains('Eve'));
    });
  });

  group('StoryBannerModel', () {
    test('initial returns empty data list', () {
      final model = StoryBannerModel.initial();
      expect(model.data, isEmpty);
    });

    test('fromJson parses empty data list without error', () {
      final model = StoryBannerModel.initial();
      model.fromJson({'status': 'Success', 'message': 'ok', 'data': []});

      expect(model.status, isTrue);
      expect(model.message, 'ok');
    });

    test('toJson returns statusCode and empty data list', () {
      final model = StoryBannerModel.initial();
      final json = model.toJson;
      expect(json['data'], isEmpty);
    });

    test('Data.fromJson and toJson round-trip all fields', () {
      final json = {
        'storyId': 1,
        'title': 'Banner',
        'shortDescription': 'Short',
        'longDescription': 'Long',
        'imageUrl': 'https://img.example.com/img.jpg',
        'sequence': 2,
        'isActive': true,
        'startDate': '2024-01-01',
        'endDate': '2024-12-31',
        'redirectionType': 'internal',
        'redirectionLink': '/home',
        'contentPlacement': 'top',
        'sourceApplication': 'Trader',
        'mapToAssets': 'asset1',
        'eventName': 'click',
        'eventParameter': 'banner_id',
        'eventParameterValue': '1',
      };

      final data = Data.fromJson(json);

      expect(data.storyId, 1);
      expect(data.title, 'Banner');
      expect(data.shortDescription, 'Short');
      expect(data.longDescription, 'Long');
      expect(data.imageUrl, 'https://img.example.com/img.jpg');
      expect(data.sequence, 2);
      expect(data.isActive, isTrue);
      expect(data.startDate, '2024-01-01');
      expect(data.endDate, '2024-12-31');
      expect(data.redirectionType, 'internal');
      expect(data.redirectionLink, '/home');
      expect(data.contentPlacement, 'top');
      expect(data.sourceApplication, 'Trader');
      expect(data.mapToAssets, 'asset1');
      expect(data.eventName, 'click');
      expect(data.eventParameter, 'banner_id');
      expect(data.eventParameterValue, '1');

      final out = data.toJson();
      expect(out['storyId'], 1);
      expect(out['title'], 'Banner');
      expect(out['isActive'], isTrue);
      expect(out['startDate'], '2024-01-01');
      expect(out['imageUrl'], 'https://img.example.com/img.jpg');
    });

    test('Data constructor with named parameters stores values', () {
      final data = Data(
        storyId: 42,
        title: 'My Banner',
        shortDescription: null,
        longDescription: null,
        imageUrl: null,
        sequence: 1,
        isActive: false,
        startDate: null,
        endDate: null,
        redirectionType: null,
        redirectionLink: null,
        contentPlacement: null,
        sourceApplication: null,
        mapToAssets: null,
        eventName: null,
        eventParameter: null,
        eventParameterValue: null,
      );

      expect(data.storyId, 42);
      expect(data.title, 'My Banner');
      expect(data.isActive, isFalse);
    });
  });
}
