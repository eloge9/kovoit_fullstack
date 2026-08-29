import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/network/dio_client.dart';
import '../models/wallet_model.dart';

class WalletRepository {
  Future<MonWalletModel> monWallet() async {
    try {
      final response = await DioClient.get(ApiConstants.monWallet);
      final raw = response.data;
      if (raw is Map<String, dynamic>) return MonWalletModel.fromJson(raw);
      throw Exception('Réponse wallet inattendue: ${raw.runtimeType}');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<WalletTransactionModel>> mesTransactions() async {
    try {
      final response = await DioClient.get(ApiConstants.mesTransactions);
      final raw = response.data;
      if (raw is List) {
        return raw
            .map((e) => WalletTransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<RetraitModel>> mesRetraits() async {
    try {
      final response = await DioClient.get(ApiConstants.mesRetraits);
      final raw = response.data;
      if (raw is List) {
        return raw.map((e) => RetraitModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Retourne (token, transref, paymentUrl, montant).
  Future<(String, String, String, double)> deposerInitier({
    required double montant,
    required String phoneNumber,
    required String network,
  }) async {
    try {
      final response = await DioClient.post(
        ApiConstants.walletDeposerInitier,
        data: {
          'montant': montant,
          'phone_number': phoneNumber,
          'network': network,
        },
      );
      final raw = response.data as Map<String, dynamic>;
      return (
        raw['token'] as String,
        raw['transref'] as String,
        raw['payment_url'] as String,
        (raw['montant'] as num?)?.toDouble() ?? montant,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Retourne true si le dépôt a été confirmé et crédité.
  Future<bool> deposerVerifier({required String token, required String transref}) async {
    try {
      final response = await DioClient.post(
        ApiConstants.walletDeposerVerifier,
        data: {'token': token, 'transref': transref},
      );
      final raw = response.data as Map<String, dynamic>;
      return raw['statut'] == 'confirme';
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<RetraitModel> demanderRetrait({
    required double montant,
    required String moyen,
    required String numeroDestination,
  }) async {
    try {
      final response = await DioClient.post(
        ApiConstants.walletRetirer,
        data: {
          'montant': montant,
          'moyen': moyen,
          'numero_destination': numeroDestination,
        },
      );
      final raw = response.data as Map<String, dynamic>;
      return RetraitModel.fromJson(raw['retrait'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
