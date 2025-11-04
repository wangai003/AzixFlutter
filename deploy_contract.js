const fs = require('fs');
const StellarSdk = require('@stellar/stellar-sdk');

// Configuration
const NETWORK = StellarSdk.Networks.TESTNET;
const RPC_URL = 'https://soroban-testnet.stellar.org';
const DISTRIBUTOR_SECRET = 'SCB3ICTKZ3FQX6R6JRBV2427JVPGN7IELDUWQOKDFGT5BGKQKWBURPIR';
const AKOFA_ISSUER = 'GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW';
const AKOFA_CODE = 'AKOFA';

async function deployMiningContract() {
  console.log('🚀 Starting Soroban mining contract deployment...');

  try {
    // Setup
    const server = new StellarSdk.Horizon.Server(RPC_URL, { allowHttp: true });
    const keypair = StellarSdk.Keypair.fromSecret(DISTRIBUTOR_SECRET);
    console.log('📝 Using account:', keypair.publicKey());

    // Load WASM file
    const wasmPath = './soroban_contracts/mining_contract/target/wasm32-unknown-unknown/release/mining_contract.wasm';
    if (!fs.existsSync(wasmPath)) {
      throw new Error(`WASM file not found at ${wasmPath}. Please build the contract first.`);
    }

    const wasmBytes = fs.readFileSync(wasmPath);
    console.log('📦 Loaded WASM file, size:', wasmBytes.length, 'bytes');

    // Get account info
    const account = await server.getAccount(keypair.publicKey());
    console.log('💰 Account sequence:', account.sequenceNumber());

    // Step 1: Upload WASM
    console.log('⬆️  Step 1: Uploading contract WASM...');
    const uploadTx = new StellarSdk.TransactionBuilder(account, {
      fee: '100000', // Higher fee for contract operations
      networkPassphrase: NETWORK
    })
    .addOperation(StellarSdk.Operation.invokeHostFunction({
      func: StellarSdk.xdr.HostFunction.hostFunctionTypeUploadContractWasm(wasmBytes),
    }))
    .setTimeout(300)
    .build();

    uploadTx.sign(keypair);
    console.log('📤 Submitting WASM upload transaction...');

    let uploadResult = await server.sendTransaction(uploadTx);

    // Wait for confirmation
    if (uploadResult.status === 'PENDING') {
      console.log('⏳ Waiting for WASM upload confirmation...');
      uploadResult = await server.getTransaction(uploadResult.hash);

      // Poll for completion
      let attempts = 0;
      while (uploadResult.status === 'NOT_FOUND' && attempts < 10) {
        await new Promise(resolve => setTimeout(resolve, 1000));
        uploadResult = await server.getTransaction(uploadResult.hash);
        attempts++;
      }
    }

    if (uploadResult.status !== 'SUCCESS') {
      throw new Error(`WASM upload failed: ${uploadResult.status}`);
    }

    // Extract WASM hash
    const wasmHash = uploadResult.resultMetaXdr.v3().sorobanMeta().events()[0].event().body().v0().data().vec()[0].bin();
    console.log('✅ WASM uploaded, hash:', wasmHash.toString('hex'));

    // Step 2: Create contract instance
    console.log('🏗️  Step 2: Creating contract instance...');

    // Refresh account sequence
    const updatedAccount = await server.getAccount(keypair.publicKey());

    const createTx = new StellarSdk.TransactionBuilder(updatedAccount, {
      fee: '100000',
      networkPassphrase: NETWORK
    })
    .addOperation(StellarSdk.Operation.invokeHostFunction({
      func: StellarSdk.xdr.HostFunction.hostFunctionTypeCreateContract(
        new StellarSdk.xdr.CreateContractArgs({
          contractIdPreimage: StellarSdk.xdr.ContractIdPreimage.contractIdPreimageFromAddress(
            new StellarSdk.xdr.ContractIdPreimageFromAddress({
              address: StellarSdk.xdr.ScAddress.scAddressTypeAccount(StellarSdk.xdr.PublicKey.publicKeyTypeEd25519(StellarSdk.xdr.Uint256.fromString(keypair.publicKey()))),
              salt: StellarSdk.xdr.Uint256.random() // Random salt for unique contract ID
            })
          ),
          executable: StellarSdk.xdr.ContractExecutable.contractExecutableWasm(StellarSdk.xdr.Hash.fromXDR(wasmHash, 'hex'))
        })
      ),
    }))
    .setTimeout(300)
    .build();

    createTx.sign(keypair);
    console.log('📤 Submitting contract creation transaction...');

    let createResult = await server.sendTransaction(createTx);

    // Wait for confirmation
    if (createResult.status === 'PENDING') {
      console.log('⏳ Waiting for contract creation confirmation...');
      createResult = await server.getTransaction(createResult.hash);

      let attempts = 0;
      while (createResult.status === 'NOT_FOUND' && attempts < 10) {
        await new Promise(resolve => setTimeout(resolve, 1000));
        createResult = await server.getTransaction(createResult.hash);
        attempts++;
      }
    }

    if (createResult.status !== 'SUCCESS') {
      throw new Error(`Contract creation failed: ${createResult.status}`);
    }

    // Extract contract ID
    const contractId = createResult.resultMetaXdr.v3().sorobanMeta().events()[0].event().body().v0().data().vec()[0].address().contractId();
    console.log('✅ Contract created, ID:', StellarSdk.StrKey.encodeContract(contractId));

    // Step 3: Initialize contract
    console.log('⚙️  Step 3: Initializing contract...');

    // Refresh account sequence again
    const finalAccount = await server.getAccount(keypair.publicKey());

    // Create contract instance for calling functions
    const contract = new StellarSdk.Contract(StellarSdk.StrKey.encodeContract(contractId));

    const initTx = new StellarSdk.TransactionBuilder(finalAccount, {
      fee: '100000',
      networkPassphrase: NETWORK
    })
    .addOperation(StellarSdk.Operation.invokeContractFunction({
      contract: StellarSdk.StrKey.encodeContract(contractId),
      function: 'initialize',
      args: [
        StellarSdk.xdr.ScVal.scvString(AKOFA_CODE), // asset_code
        StellarSdk.xdr.ScVal.scvString(AKOFA_ISSUER), // asset_issuer
        StellarSdk.xdr.ScVal.scvU64(new StellarSdk.xdr.Uint64(2500000)) // mining_rate (0.25 * 10^7)
      ],
    }))
    .setTimeout(300)
    .build();

    initTx.sign(keypair);
    console.log('📤 Submitting contract initialization...');

    let initResult = await server.sendTransaction(initTx);

    // Wait for confirmation
    if (initResult.status === 'PENDING') {
      console.log('⏳ Waiting for initialization confirmation...');
      initResult = await server.getTransaction(initResult.hash);

      let attempts = 0;
      while (initResult.status === 'NOT_FOUND' && attempts < 10) {
        await new Promise(resolve => setTimeout(resolve, 1000));
        initResult = await server.getTransaction(initResult.hash);
        attempts++;
      }
    }

    if (initResult.status !== 'SUCCESS') {
      throw new Error(`Contract initialization failed: ${initResult.status}`);
    }

    console.log('✅ Contract initialized successfully!');

    // Final output
    const finalContractId = StellarSdk.StrKey.encodeContract(contractId);
    console.log('\n🎉 DEPLOYMENT COMPLETE!');
    console.log('📋 Contract Details:');
    console.log('   Contract ID:', finalContractId);
    console.log('   Network: Stellar Testnet');
    console.log('   AKOFA Asset:', `${AKOFA_CODE}:${AKOFA_ISSUER}`);
    console.log('   Mining Rate: 0.25 AKOFA/hour');

    // Save to file for easy reference
    const deploymentInfo = {
      contractId: finalContractId,
      network: 'testnet',
      akofaAsset: `${AKOFA_CODE}:${AKOFA_ISSUER}`,
      miningRate: '0.25 AKOFA/hour',
      deployedAt: new Date().toISOString(),
      wasmHash: wasmHash.toString('hex')
    };

    fs.writeFileSync('./contract_deployment.json', JSON.stringify(deploymentInfo, null, 2));
    console.log('💾 Deployment info saved to contract_deployment.json');

    return finalContractId;

  } catch (error) {
    console.error('❌ Deployment failed:', error);
    throw error;
  }
}

// Run deployment if called directly
if (require.main === module) {
  deployMiningContract()
    .then(() => {
      console.log('✅ Deployment script completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Deployment script failed:', error);
      process.exit(1);
    });
}

module.exports = { deployMiningContract };