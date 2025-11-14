/// Models for LI.FI route responses and bridge operations

/// Quote request for LI.FI API
class QuoteRequest {
  final String fromChain;
  final String toChain;
  final String fromToken;
  final String toToken;
  final String fromAmount;
  final String fromAddress;
  final String toAddress;
  final String? order;
  final List<String>? allowBridges;
  final List<String>? denyBridges;
  final List<String>? allowExchanges;
  final List<String>? denyExchanges;
  final bool? slippage;
  final String? integrator;

  QuoteRequest({
    required this.fromChain,
    required this.toChain,
    required this.fromToken,
    required this.toToken,
    required this.fromAmount,
    required this.fromAddress,
    required this.toAddress,
    this.order,
    this.allowBridges,
    this.denyBridges,
    this.allowExchanges,
    this.denyExchanges,
    this.slippage,
    this.integrator,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'fromChain': fromChain,
      'toChain': toChain,
      'fromToken': fromToken,
      'toToken': toToken,
      'fromAmount': fromAmount,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
    };
    
    if (order != null) map['order'] = order;
    if (allowBridges != null) map['allowBridges'] = allowBridges;
    if (denyBridges != null) map['denyBridges'] = denyBridges;
    if (allowExchanges != null) map['allowExchanges'] = allowExchanges;
    if (denyExchanges != null) map['denyExchanges'] = denyExchanges;
    if (slippage != null) map['slippage'] = slippage;
    if (integrator != null) map['integrator'] = integrator;
    
    return map;
  }
}

/// Route response from LI.FI
class BridgeRoute {
  final String id;
  final List<BridgeStep> steps;
  final Estimate estimate;
  final Map<String, dynamic>? transactionRequest;
  final String? integrator;
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'steps': steps.map((s) => s.toJson()).toList(),
      'estimate': {
        'fromAmount': estimate.fromAmount,
        'toAmount': estimate.toAmount,
      },
      'transactionRequest': transactionRequest,
      'integrator': integrator,
    };
  }

  BridgeRoute({
    required this.id,
    required this.steps,
    required this.estimate,
    this.transactionRequest,
    this.integrator,
  });

  factory BridgeRoute.fromJson(Map<String, dynamic> json) {
    return BridgeRoute(
      id: json['id'] as String,
      steps: (json['steps'] as List<dynamic>)
          .map((step) => BridgeStep.fromJson(step as Map<String, dynamic>))
          .toList(),
      estimate: Estimate.fromJson(json['estimate'] as Map<String, dynamic>),
      transactionRequest: json['transactionRequest'] as Map<String, dynamic>?,
      integrator: json['integrator'] as String?,
    );
  }
}

/// Single step in a route
class BridgeStep {
  final String id;
  final String type; // 'swap', 'cross', 'custom'
  final String tool;
  final String toolDetails;
  final Action action;
  final Estimate estimate;
  final Map<String, dynamic>? transactionRequest;
  final List<Map<String, dynamic>>? transactions;
  
  final String? includedSteps;
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'tool': tool,
      'toolDetails': toolDetails,
      'action': action.toJson(),
      'estimate': {
        'fromAmount': estimate.fromAmount,
        'toAmount': estimate.toAmount,
      },
      'transactionRequest': transactionRequest,
      'transactions': transactions,
    };
  }

  BridgeStep({
    required this.id,
    required this.type,
    required this.tool,
    required this.toolDetails,
    required this.action,
    required this.estimate,
    this.transactionRequest,
    this.transactions,
    this.includedSteps,
  });

  factory BridgeStep.fromJson(Map<String, dynamic> json) {
    return BridgeStep(
      id: json['id'] as String,
      type: json['type'] as String,
      tool: json['tool'] as String,
      toolDetails: json['toolDetails'] as String? ?? '',
      action: Action.fromJson(json['action'] as Map<String, dynamic>),
      estimate: Estimate.fromJson(json['estimate'] as Map<String, dynamic>),
      transactionRequest: json['transactionRequest'] as Map<String, dynamic>?,
      transactions: json['transactions'] != null
          ? (json['transactions'] as List<dynamic>)
              .map((tx) => tx as Map<String, dynamic>)
              .toList()
          : null,
      includedSteps: json['includedSteps'] as String?,
    );
  }
  
  /// Check if this step requires Stellar signing
  bool requiresStellarSigning() {
    if (transactionRequest != null) {
      final type = transactionRequest!['type'] as String?;
      return type == 'stellar_xdr' || type == 'stellar';
    }
    
    // Check if tool is Stellar-related
    return tool.toLowerCase().contains('stellar') ||
           tool.toLowerCase().contains('allbridge');
  }
  
  /// Check if this step requires EVM signing
  bool requiresEvmSigning() {
    if (transactionRequest != null) {
      final type = transactionRequest!['type'] as String?;
      return type == 'evm' || type == 'ethereum' || type == 'polygon';
    }
    
    if (transactions != null && transactions!.isNotEmpty) {
      return true; // EVM transactions are in transactions array
    }
    
    return false;
  }
  
  /// Get deposit address if provided
  String? getDepositAddress() {
    if (transactionRequest != null) {
      return transactionRequest!['depositAddress'] as String?;
    }
    return action.to?.address;
  }
}

/// Action details for a step
class Action {
  final Token from;
  final Token to;
  final String? slippage;
  final String? amount;

  Action({
    required this.from,
    required this.to,
    this.slippage,
    this.amount,
  });

  factory Action.fromJson(Map<String, dynamic> json) {
    return Action(
      from: Token.fromJson(json['from'] as Map<String, dynamic>),
      to: Token.fromJson(json['to'] as Map<String, dynamic>),
      slippage: json['slippage'] as String?,
      amount: json['amount'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'from': from.toJson(),
      'to': to.toJson(),
      'slippage': slippage,
      'amount': amount,
    };
  }
}

/// Token information
class Token {
  final String address;
  final String symbol;
  final int decimals;
  final String chainId;
  final String? name;
  final String? logoURI;
  final double? priceUSD;
  
  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'symbol': symbol,
      'decimals': decimals,
      'chainId': chainId,
      'name': name,
      'logoURI': logoURI,
      'priceUSD': priceUSD,
    };
  }

  Token({
    required this.address,
    required this.symbol,
    required this.decimals,
    required this.chainId,
    this.name,
    this.logoURI,
    this.priceUSD,
  });

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      address: json['address'] as String,
      symbol: json['symbol'] as String,
      decimals: json['decimals'] as int? ?? 18,
      chainId: json['chainId'] as String,
      name: json['name'] as String?,
      logoURI: json['logoURI'] as String?,
      priceUSD: (json['priceUSD'] as num?)?.toDouble(),
    );
  }
}

/// Estimate for route/step
class Estimate {
  final String fromAmount;
  final String toAmount;
  final String? toAmountMin;
  final String? toAmountMax;
  final Map<String, dynamic>? approvalAddress;
  final Map<String, dynamic>? feeCosts;
  final Map<String, dynamic>? gasCosts;
  final Duration? executionDuration;

  Estimate({
    required this.fromAmount,
    required this.toAmount,
    this.toAmountMin,
    this.toAmountMax,
    this.approvalAddress,
    this.feeCosts,
    this.gasCosts,
    this.executionDuration,
  });

  factory Estimate.fromJson(Map<String, dynamic> json) {
    Duration? executionDuration;
    if (json['executionDuration'] != null) {
      final seconds = (json['executionDuration'] as num).toInt();
      executionDuration = Duration(seconds: seconds);
    }
    
    return Estimate(
      fromAmount: json['fromAmount'] as String,
      toAmount: json['toAmount'] as String,
      toAmountMin: json['toAmountMin'] as String?,
      toAmountMax: json['toAmountMax'] as String?,
      approvalAddress: json['approvalAddress'] as Map<String, dynamic>?,
      feeCosts: json['feeCosts'] as Map<String, dynamic>?,
      gasCosts: json['gasCosts'] as Map<String, dynamic>?,
      executionDuration: executionDuration,
    );
  }
  
  /// Get total fees in USD
  double? getTotalFeesUSD() {
    double total = 0.0;
    
    if (feeCosts != null) {
      final amount = feeCosts!['amountUSD'] as num?;
      if (amount != null) total += amount.toDouble();
    }
    
    if (gasCosts != null) {
      final amount = gasCosts!['amountUSD'] as num?;
      if (amount != null) total += amount.toDouble();
    }
    
    return total > 0 ? total : null;
  }
}

/// Transaction request for signing
class TransactionRequest {
  final String type; // 'stellar_xdr', 'evm', etc.
  final String? xdr; // For Stellar
  final String? to; // For EVM
  final String? data; // For EVM
  final String? value; // For EVM
  final String? chainId; // For EVM
  final String? gas; // For EVM
  final String? gasPrice; // For EVM
  final Map<String, dynamic>? additionalData;

  TransactionRequest({
    required this.type,
    this.xdr,
    this.to,
    this.data,
    this.value,
    this.chainId,
    this.gas,
    this.gasPrice,
    this.additionalData,
  });

  factory TransactionRequest.fromJson(Map<String, dynamic> json) {
    return TransactionRequest(
      type: json['type'] as String,
      xdr: json['xdr'] as String?,
      to: json['to'] as String?,
      data: json['data'] as String?,
      value: json['value'] as String?,
      chainId: json['chainId'] as String?,
      gas: json['gas'] as String?,
      gasPrice: json['gasPrice'] as String?,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }
}

