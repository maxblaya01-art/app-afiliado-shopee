import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const ShopeeApp());
}

class ShopeeApp extends StatelessWidget {
  const ShopeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Divulgador Shopee',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFFFFF8F5),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _LinhaOCR {
  final String texto;
  final Rect caixa;

  _LinhaOCR({
    required this.texto,
    required this.caixa,
  });
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _linkController = TextEditingController();

  File? _imagem;

  String _nomeProduto = '';
  String _preco = '';
  String _textoLido = '';

  bool _carregando = false;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  // ============================================================
  // ESCOLHER PRINT
  // ============================================================

  Future<void> _escolherPrint() async {
    try {
      final XFile? arquivo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (arquivo == null) {
        return;
      }

      setState(() {
        _imagem = File(arquivo.path);
        _carregando = true;
        _nomeProduto = '';
        _preco = '';
        _textoLido = '';
      });

      await _lerTextoDaImagem(arquivo.path);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
      });

      _mostrarMensagem(
        'Não foi possível ler o print.\n\n$e',
      );
    }
  }

  // ============================================================
  // NORMALIZAR TEXTO DO OCR
  // ============================================================

  String _normalizarTexto(String texto) {
    String resultado = texto;

    resultado = resultado
        .replaceAll('Á', 'á')
        .replaceAll('À', 'à')
        .replaceAll('Ã', 'ã')
        .replaceAll('Â', 'â')
        .replaceAll('É', 'é')
        .replaceAll('Ê', 'ê')
        .replaceAll('Í', 'í')
        .replaceAll('Ó', 'ó')
        .replaceAll('Ô', 'ô')
        .replaceAll('Õ', 'õ')
        .replaceAll('Ú', 'ú')
        .replaceAll('Ç', 'ç');

    resultado = resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return resultado.trim();
  }

  // ============================================================
  // LIMPAR LINHA
  // ============================================================

  String _limparLinha(String texto) {
    String resultado = _normalizarTexto(texto);

    if (resultado.isEmpty) {
      return '';
    }

    // ----------------------------------------------------------
    // REMOVE COMISSÃO EXTRA EM TODAS AS FORMAS MAIS COMUNS
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'comiss[aã]o\s*extra',
        caseSensitive: false,
      ),
      ' ',
    );

    resultado = resultado.replaceAll(
      RegExp(
        r'comiss[aã]o\s*ex\s*tra',
        caseSensitive: false,
      ),
      ' ',
    );

    resultado = resultado.replaceAll(
      RegExp(
        r'comiss[aã]oex\s*tra',
        caseSensitive: false,
      ),
      ' ',
    );

    resultado = resultado.replaceAll(
      RegExp(
        r'comiss[aã]o\s*ex\s*tr[aã]',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE FORMAS EM QUE O OCR JUNTOU TUDO
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'comiss[aã]oextra',
        caseSensitive: false,
      ),
      ' ',
    );

    resultado = resultado.replaceAll(
      RegExp(
        r'comissaoextra',
        caseSensitive: false,
      ),
      ' ',
    );

    resultado = resultado.replaceAll(
      RegExp(
        r'comissaoex\W*tra',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE PORCENTAGEM
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'\b\d{1,3}(?:[.,]\d+)?\s*%',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE EXPRESSÕES DE COMISSÃO
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'\bcomiss[aã]o\b',
        caseSensitive: false,
      ),
      ' ',
    );

    resultado = resultado.replaceAll(
      RegExp(
        r'\bextra\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE TEXTOS DE INTERFACE
    // ----------------------------------------------------------

    final palavrasRemover = [
      'shopee',
      'afiliados',
      'afiliado',
      'promoveram',
      'mais vendidos',
      'vendido',
      'vendidos',
      'aprenda com outros criadores',
      'compartilhe para ganhar',
      'compartilhar',
      'compartilhe',
      'favorito',
      'chat',
      'cupom',
      'oferta',
      'promoção',
      'promocao',
      'frete grátis',
      'frete gratis',
      'comprar agora',
      'adicionar ao carrinho',
      'parcelado',
      'entrega',
    ];

    for (final palavra in palavrasRemover) {
      resultado = resultado.replaceAll(
        RegExp(
          RegExp.escape(palavra),
          caseSensitive: false,
        ),
        ' ',
      );
    }

    // ----------------------------------------------------------
    // REMOVE LINKS
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'https?://\S+',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE PREÇOS
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'R\$\s*\d+(?:[.,]\d{2})?',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE NÚMEROS DE INTERFACE
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'\b(?:no|nº|n°)\.?\s*\d+\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // LIMPEZA FINAL
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(r'\.{2,}$'),
      '',
    );

    resultado = resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    resultado = resultado.trim();

    resultado = resultado.replaceAll(
      RegExp(r'^[,;:.\-]+'),
      '',
    );

    resultado = resultado.replaceAll(
      RegExp(r'[,;:.\-]+$'),
      '',
    );

    return resultado.trim();
  }

  // ============================================================
  // VERIFICAR TEXTO QUE NÃO É NOME
  // ============================================================

  bool _ehTextoIgnorado(String texto) {
    final t = _normalizarTexto(texto).toLowerCase();

    if (t.isEmpty) {
      return true;
    }

    // Comissão.
    if (t.contains('comissão') ||
        t.contains('comissao') ||
        t.contains('extra')) {
      return true;
    }

    // Porcentagem.
    if (RegExp(
      r'\d+(?:[.,]\d+)?\s*%',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }

    // Preço.
    if (RegExp(
      r'r\$\s*\d',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }

    final palavras = [
      'shopee',
      'afiliado',
      'afiliados',
      'promoveram',
      'vendido',
      'vendidos',
      'mais vendidos',
      'aprenda com outros criadores',
      'compartilhe',
      'compartilhar',
      'favorito',
      'chat',
      'cupom',
      'oferta',
      'promoção',
      'promocao',
      'frete grátis',
      'frete gratis',
      'comprar agora',
      'adicionar ao carrinho',
      'parcelado',
      'entrega',
    ];

    for (final palavra in palavras) {
      if (t.contains(palavra)) {
        return true;
      }
    }

    if (t.length < 3) {
      return true;
    }

    return false;
  }

  // ============================================================
  // CORRIGIR NOME
  // ============================================================

  String _ajustarNomeProduto(String nome) {
    String resultado = _limparLinha(nome);

    if (resultado.isEmpty) {
      return '';
    }

    resultado = resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    ).trim();

    // ----------------------------------------------------------
    // CORES
    //
    // Se o OCR colocar "Preto" no começo:
    //
    // Preto Kit 2 Pendente Lustre...
    //
    // transforma em:
    //
    // Kit 2 Pendente Lustre... Preto
    // ----------------------------------------------------------

    final cores = [
      'preto',
      'preta',
      'branco',
      'branca',
      'azul',
      'vermelho',
      'vermelha',
      'verde',
      'rosa',
      'roxo',
      'roxa',
      'amarelo',
      'amarela',
      'cinza',
      'prata',
      'dourado',
      'dourada',
      'bege',
      'marrom',
    ];

    final palavras = resultado.split(' ');

    if (palavras.length >= 3) {
      final primeira = palavras.first.toLowerCase();

      if (cores.contains(primeira)) {
        final resto = palavras.skip(1).join(' ');

        final pareceProduto = RegExp(
          r'\b(kit|pende[nr]te|lustre|luminária|luminaria|aramado|diamante|mesa|projetor|ventilador|notebook|celular|fone|câmera|camera)\b',
          caseSensitive: false,
        ).hasMatch(resto);

        if (pareceProduto) {
          resultado = '$resto ${palavras.first}';
        }
      }
    }

    // ----------------------------------------------------------
    // REMOVE PALAVRA REPETIDA NO FINAL
    // ----------------------------------------------------------

    final lista = resultado.split(' ');

    if (lista.length >= 4) {
      final ultima = lista.last.toLowerCase();

      for (int i = 0; i < lista.length - 1; i++) {
        if (lista[i].toLowerCase() == ultima) {
          lista.removeLast();
          break;
        }
      }

      resultado = lista.join(' ');
    }

    // ----------------------------------------------------------
    // LIMPEZA FINAL
    // ----------------------------------------------------------

    resultado = _limparLinha(resultado);

    return resultado;
  }

  // ============================================================
  // ENCONTRAR NOME DO PRODUTO
  // ============================================================

  String _encontrarNomeProduto(
    List<_LinhaOCR> linhas,
    int indicePreco,
    double parteInferiorPreco,
  ) {
    final List<String> partes = [];

    // ----------------------------------------------------------
    // O TÍTULO DO PRODUTO FICA ABAIXO DO PREÇO.
    //
    // A COMISSÃO EXTRA FICA NA MESMA ALTURA DO PREÇO.
    //
    // Portanto não devemos simplesmente pegar todas as linhas
    // próximas. Primeiro filtramos as linhas abaixo do preço.
    // ----------------------------------------------------------

    for (int i = 0; i < linhas.length; i++) {
      final linhaOCR = linhas[i];

      if (indicePreco >= 0) {
        if (linhaOCR.caixa.top < parteInferiorPreco - 3) {
          continue;
        }
      }

      final original = linhaOCR.texto.trim();

      if (original.isEmpty) {
        continue;
      }

      if (_ehTextoIgnorado(original)) {
        continue;
      }

      String linha = _limparLinha(original);

      if (linha.isEmpty) {
        continue;
      }

      if (_ehTextoIgnorado(linha)) {
        continue;
      }

      // Não aceitar linhas gigantes de interface.
      if (linha.length > 120) {
        continue;
      }

      // --------------------------------------------------------
      // CORREÇÃO ESPECÍFICA PARA O PROBLEMA DA FOTO
      //
      // Se uma linha tiver "COMISSÃO EXTRA" misturado com
      // palavras do produto, removemos a parte da comissão.
      // --------------------------------------------------------

      linha = linha.replaceAll(
        RegExp(
          r'comiss[aã]o.*?(?=\bkit\b|\bpende[nr]te\b|\blustre\b|\bluminária\b|\bluminaria\b)',
          caseSensitive: false,
        ),
        '',
      );

      linha = _limparLinha(linha);

      if (linha.isEmpty) {
        continue;
      }

      partes.add(linha);

      // Normalmente o título ocupa no máximo 3 ou 4 linhas.
      if (partes.length >= 4) {
        break;
      }
    }

    String nome = partes.join(' ');

    return _ajustarNomeProduto(nome);
  }

  // ============================================================
  // OCR PRINCIPAL
  // ============================================================

  Future<void> _lerTextoDaImagem(String caminho) async {
    final TextRecognizer reconhecedor = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final InputImage imagem = InputImage.fromFilePath(caminho);

      final RecognizedText resultado =
          await reconhecedor.processImage(imagem);

      final String textoCompleto = resultado.text.trim();

      final List<_LinhaOCR> linhas = [];

      for (final bloco in resultado.blocks) {
        for (final linha in bloco.lines) {
          final texto = linha.text.trim();

          if (texto.isEmpty) {
            continue;
          }

          linhas.add(
            _LinhaOCR(
              texto: texto,
              caixa: linha.boundingBox,
            ),
          );
        }
      }

      // Ordenar de cima para baixo.
      linhas.sort((a, b) {
        final y = a.caixa.top.compareTo(b.caixa.top);

        if (y != 0) {
          return y;
        }

        return a.caixa.left.compareTo(b.caixa.left);
      });

      // ========================================================
      // PREÇO
      // ========================================================

      final RegExp regexPreco = RegExp(
        r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
        caseSensitive: false,
      );

      String preco = '';
      int indicePreco = -1;
      double parteInferiorPreco = 0;

      for (int i = 0; i < linhas.length; i++) {
        final texto = linhas[i].texto;

        final match = regexPreco.firstMatch(texto);

        if (match != null) {
          preco = match.group(0) ?? '';

          if (preco.isNotEmpty) {
            indicePreco = i;
            parteInferiorPreco = linhas[i].caixa.bottom;
            break;
          }
        }
      }

      // ========================================================
      // NOME
      // ========================================================

      String nome = _encontrarNomeProduto(
        linhas,
        indicePreco,
        parteInferiorPreco,
      );

      // ========================================================
      // FALLBACK
      // ========================================================

      if (nome.isEmpty) {
        final List<String> fallback = [];

        for (final linhaOCR in linhas) {
          if (_ehTextoIgnorado(linhaOCR.texto)) {
            continue;
          }

          final linha = _limparLinha(linhaOCR.texto);

          if (linha.isEmpty) {
            continue;
          }

          if (_ehTextoIgnorado(linha)) {
            continue;
          }

          if (linha.length < 5) {
            continue;
          }

          fallback.add(linha);

          if (fallback.length >= 3) {
            break;
          }
        }

        nome = _ajustarNomeProduto(
          fallback.join(' '),
        );
      }

      // ========================================================
      // LIMPEZA ESPECIAL FINAL
      // ========================================================

      nome = nome.replaceAll(
        RegExp(
          r'comiss[aã]o\s*ex\s*tra',
          caseSensitive: false,
        ),
        '',
      );

      nome = nome.replaceAll(
        RegExp(
          r'comiss[aã]oextra',
          caseSensitive: false,
        ),
        '',
      );

      nome = nome.replaceAll(
        RegExp(
          r'\d{1,3}(?:[.,]\d+)?\s*%',
          caseSensitive: false,
        ),
        '',
      );

      nome = _ajustarNomeProduto(nome);

      // ========================================================
      // LIMITE
      // ========================================================

      if (nome.length > 180) {
        nome = nome.substring(0, 180).trim();

        final ultimoEspaco = nome.lastIndexOf(' ');

        if (ultimoEspaco > 20) {
          nome = nome.substring(0, ultimoEspaco).trim();
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _textoLido = textoCompleto;
        _nomeProduto = nome;
        _preco = preco;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregando = false;
      });

      _mostrarMensagem(
        'Erro ao reconhecer o texto do print.\n\n$e',
      );
    } finally {
      await reconhecedor.close();
    }
  }

  // ============================================================
  // LINK
  // ============================================================

  String _obterLink() {
    String link = _linkController.text.trim();

    if (link.isEmpty) {
      return '';
    }

    if (!link.startsWith('http://') &&
        !link.startsWith('https://')) {
      link = 'https://$link';
    }

    return link;
  }

  // ============================================================
  // TEXTO DA DIVULGAÇÃO
  // ============================================================

  String _gerarTextoDivulgacao() {
    final String nome = _nomeProduto.isEmpty
        ? 'Produto Shopee'
        : _nomeProduto;

    final String preco = _preco.isEmpty
        ? 'Confira o preço'
        : _preco;

    final String link = _obterLink();

    return '''
🛍️ $nome

🔥 OFERTA NA SHOPEE 🔥

💰 $preco

👇 Confira aqui:
$link

🛒 Aproveite a oferta!
'''.trim();
  }

  // ============================================================
  // COMPARTILHAR FOTO
  // ============================================================

  Future<void> _compartilharFoto() async {
    final String link = _obterLink();

    if (link.isEmpty) {
      _mostrarMensagem(
        'Digite o seu link de afiliado antes de compartilhar.',
      );
      return;
    }

    if (_imagem == null) {
      _mostrarMensagem(
        'Escolha o print do produto primeiro.',
      );
      return;
    }

    final String texto = _gerarTextoDivulgacao();

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: texto,
          subject: 'Oferta Shopee - $_nomeProduto',
          files: [
            XFile(_imagem!.path),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensagem(
        'Não foi possível compartilhar.\n\n$e',
      );
    }
  }

  // ============================================================
  // COMPARTILHAR TEXTO
  // ============================================================

  Future<void> _compartilharTexto() async {
    final String link = _obterLink();

    if (link.isEmpty) {
      _mostrarMensagem(
        'Digite o seu link de afiliado primeiro.',
      );
      return;
    }

    final String texto = _gerarTextoDivulgacao();

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: texto,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensagem(
        'Não foi possível compartilhar.\n\n$e',
      );
    }
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================
  // CAMPO LINK
  // ============================================================

  Widget _campoLink() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _linkController,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: 'Link de afiliado Shopee',
          hintText: 'Cole seu link aqui',
          prefixIcon: const Icon(Icons.link),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  // ============================================================
  // CARD INFORMAÇÕES
  // ============================================================

  Widget _cardInformacoes() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EC),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INFORMAÇÕES ENCONTRADAS',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'NOME DO PRODUTO',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            _nomeProduto.isEmpty
                ? 'Produto não identificado'
                : _nomeProduto,
            style: const TextStyle(
              fontSize: 28,
              height: 1.35,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
            ),
          ),

          const SizedBox(height: 30),

          Text(
            'PREÇO',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            _preco.isEmpty ? 'Preço não identificado' : _preco,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF4F20),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTÃO ESCOLHER PRINT
  // ============================================================

  Widget _botaoEscolher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _carregando ? null : _escolherPrint,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 28,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0EB),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.image_outlined,
                size: 28,
                color: Color(0xFF8A4A3A),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _carregando
                      ? 'LENDO PRODUTO...'
                      : 'ESCOLHER FOTO / PRINT DO PRODUTO',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8A4A3A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGEM
  // ============================================================

  Widget _imagemProduto() {
    if (_imagem == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        _imagem!,
        width: double.infinity,
        fit: BoxFit.contain,
      ),
    );
  }

  // ============================================================
  // TEXTO OCR
  // ============================================================

  Widget _textoDetectado() {
    if (_textoLido.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      title: const Text(
        'Ver texto detectado no print',
        style: TextStyle(
          fontSize: 18,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _textoLido,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTÕES
  // ============================================================

  Widget _botoesCompartilhar() {
    if (_imagem == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 30),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 62,
            child: ElevatedButton.icon(
              onPressed: _compartilharFoto,
              icon: const Icon(
                Icons.image,
                color: Colors.white,
              ),
              label: const Text(
                'COMPARTILHAR FOTO + DIVULGAÇÃO',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4F20),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: OutlinedButton.icon(
              onPressed: _compartilharTexto,
              icon: const Icon(Icons.share),
              label: const Text(
                'COMPARTILHAR SOMENTE TEXTO',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF4F20),
                side: const BorderSide(
                  color: Color(0xFFFF4F20),
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TELA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF4F20),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 28),

              _campoLink(),

              const SizedBox(height: 26),

              _botaoEscolher(),

              if (_imagem == null)
                const Padding(
                  padding: EdgeInsets.fromLTRB(35, 180, 35, 40),
                  child: Text(
                    'O aplicativo tenta separar somente o produto,\n'
                    'remove textos como COMISSÃO EXTRA do nome e\n'
                    'cria uma nova imagem com o nome na faixa verde.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                ),

              _imagemProduto(),

              if (_imagem != null) _cardInformacoes(),

              _textoDetectado(),

              _botoesCompartilhar(),
            ],
          ),
        ),
      ),
    );
  }
}
