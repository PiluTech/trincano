// Ferramenta mínima Ed25519 (CryptoKit) para os scripts de atualização.
//   ed25519 pub <chave-privada-base64>                       -> imprime a chave pública (base64)
//   ed25519 verify <pública-base64> <assinatura-base64> <arquivo> -> sai 0 se válida, 1 se não
import CryptoKit
import Foundation

let args = CommandLine.arguments
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}
guard args.count >= 3 else { fail("uso: ed25519 pub <seed> | verify <pub> <sig> <arquivo>") }
switch args[1] {
case "pub":
    guard let seed = Data(base64Encoded: args[2].trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: seed.prefix(32))
    else { fail("chave privada inválida") }
    print(key.publicKey.rawRepresentation.base64EncodedString())
case "verify":
    guard args.count == 5,
          let pub = Data(base64Encoded: args[2]),
          let key = try? Curve25519.Signing.PublicKey(rawRepresentation: pub),
          let sig = Data(base64Encoded: args[3]),
          let data = try? Data(contentsOf: URL(fileURLWithPath: args[4]))
    else { fail("argumentos inválidos") }
    exit(key.isValidSignature(sig, for: data) ? 0 : 1)
default:
    fail("modo desconhecido: \(args[1])")
}
