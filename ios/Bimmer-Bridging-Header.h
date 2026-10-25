//
//  Bimmer-Bridging-Header.h
//  引入 CommonCrypto 以使用 AES-128-CBC(CryptoKit 只支持 GCM,nonce 算法需要 CBC)。
//

#import <CommonCrypto/CommonCrypto.h>
