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
  // LIMPAR TEXTO DO OCR
  // ============================================================

  String _limparLinha(String texto) {
    String resultado = texto.trim();

    // Remove comissão extra mesmo quando o OCR junta as palavras.
    resultado = resultado.replaceAll(
      RegExp(
        r'comiss[aã]o\s*ex\s*tra',
        caseSensitive: false,
      ),
      ' ',
    );

    resultado = resultado.replaceAll(
      RegExp(
        r'comiss[aã]o\s*extra',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove algumas formas comuns de erro do OCR.
    resultado = resultado.replaceAll(
      RegExp(
        r'comiss[aã]oex\s*tra',
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

    // Remove porcentagens.
    resultado = resultado.replaceAll(
      RegExp(
        r'\b\d{1,3}(?:[.,]\d+)?\s*%',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove No.11, No 11, Nº11 etc.
    resultado = resultado.replaceAll(
      RegExp(
        r'\b(?:no|nº|n°)\.?\s*\d+\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove palavras que aparecem em elementos da Shopee.
    resultado = resultado.replaceAll(
      RegExp(
        r'\b(?:comissão|comissao|extra)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove alguns textos de interface que podem entrar no OCR.
    final palavrasRemover = [
      'mais vendidos',
      'aprenda com outros criadores',
      'compartilhe para ganhar',
      'compartilhar',
      'favorito',
      'chat',
      'afiliados promoveram',
      'vendido',
      'vendidos',
      'avaliações',
      'avaliacoes',
      'oferta',
      'cupom',
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

    // Remove links.
    resultado = resultado.replaceAll(
      RegExp(
        r'https?://\S+',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove reticências do final.
    resultado = resultado.replaceAll(
      RegExp(r'\.{2,}$'),
      '',
    );

    // Junta espaços.
    resultado = resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    resultado = resultado.trim();

    // Remove pontuação isolada no começo/fim.
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
  // VERIFICAR SE É TEXTO DE INTERFACE
  // ============================================================

  bool _ehTextoIgnorado(String texto) {
    final t = texto.toLowerCase().trim();

    if (t.isEmpty) {
      return true;
    }

    // Preço.
    if (RegExp(
      r'(?:r\$|\d{1,3}(?:[.\s]\d{3})*,\d{2})',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }

    // Porcentagem.
    if (RegExp(r'\d+(?:[.,]\d+)?\s*%').hasMatch(t)) {
      return true;
    }

    final palavras = [
      'comissão extra',
      'comissao extra',
      'comissãoextra',
      'comissaoextra',
      'shopee',
      'afiliados',
      'afiliado',
      'promoveram',
      'vendido',
      'vendidos',
      'mais vendidos',
      'avaliações',
      'avaliacoes',
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
      'adicionar ao carrinho',
      'comprar agora',
      'parcelado',
      'entrega',
      '4.9',
      '4,9',
      '4.8',
      '4,8',
      '5.0',
      '5,0',
    ];

    for (final palavra in palavras) {
      if (t.contains(palavra)) {
        return true;
      }
    }

    // Linhas muito curtas normalmente são ícones/badges.
    if (t.length < 3) {
      return true;
    }

    return false;
  }

  // ============================================================
  // AJUSTAR NOME DO PRODUTO
  // ============================================================

  String _ajustarNomeProduto(String nome) {
    String resultado = _limparLinha(nome);

    if (resultado.isEmpty) {
      return '';
    }

    // Corrige espaços duplicados.
    resultado = resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    ).trim();

    // ----------------------------------------------------------
    // Se o OCR colocou uma cor no começo por causa da mistura
    // com a faixa de comissão, coloca a cor no final.
    // Exemplo:
    // "Preto Kit 2 Pendente Lustre"
    // vira:
    // "Kit 2 Pendente Lustre Preto"
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

        final pareceTitulo = RegExp(
          r'\b(kit|pende[nr]te|lustre|luminária|luminaria|mesa|projetor|ventilador|notebook|celular|fone|câmera|camera)\b',
          caseSensitive: false,
        ).hasMatch(resto);

        if (pareceTitulo) {
          resultado = '$resto ${palavras.first}';
        }
      }
    }

    // ----------------------------------------------------------
    // Remove palavras repetidas no final.
    //
    // Exemplo:
    // "Kit 2 Pendente Lustre Luminária Aramado Diamante Pendente"
    //
    // vira:
    // "Kit 2 Pendente Lustre Luminária Aramado Diamante"
    // ----------------------------------------------------------

    final palavrasFinais = resultado.split(' ');

    if (palavrasFinais.length >= 4) {
      final ultima = palavrasFinais.last.toLowerCase();

      final apareceuAntes = palavrasFinais
          .sublist(0, palavrasFinais.length - 1)
          .map((e) => e.toLowerCase())
          .contains(ultima);

      if (apareceuAntes) {
        palavrasFinais.removeLast();
        resultado = palavrasFinais.join(' ');
      }
    }

    // Remove novamente possíveis espaços.
    resultado = resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    ).trim();

    return resultado;
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

      // --------------------------------------------------------
      // Pegamos cada linha junto com sua posição no print.
      // Isso é o que evita pegar texto de cima, comissão extra
      // e textos que estão em outras partes da tela.
      // --------------------------------------------------------

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

      // Ordena visualmente: primeiro de cima para baixo,
      // depois da esquerda para a direita.
      linhas.sort((a, b) {
        final diferencaY = a.caixa.top.compareTo(b.caixa.top);

        if (diferencaY != 0) {
          return diferencaY;
        }

        return a.caixa.left.compareTo(b.caixa.left);
      });

      // --------------------------------------------------------
      // PREÇO
      // --------------------------------------------------------

      final RegExp regexPreco = RegExp(
        r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
        caseSensitive: false,
      );

      String preco = '';
      int indiceLinhaPreco = -1;
      double parteInferiorPreco = 0;

      for (int i = 0; i < linhas.length; i++) {
        final linha = linhas[i].texto;

        final match = regexPreco.firstMatch(linha);

        if (match != null) {
          preco = match.group(0) ?? '';

          if (preco.isNotEmpty) {
            indiceLinhaPreco = i;
            parteInferiorPreco = linhas[i].caixa.bottom;
            break;
          }
        }
      }

      // --------------------------------------------------------
      // NOME DO PRODUTO
      // --------------------------------------------------------

      final List<String> partesNome = [];

      // Se encontramos o preço, procuramos o título abaixo dele.
      if (indiceLinhaPreco >= 0) {
        for (int i = 0; i < linhas.length; i++) {
          final linhaOCR = linhas[i];

          // Tem que estar abaixo da linha do preço.
          if (linhaOCR.caixa.top < parteInferiorPreco - 5) {
            continue;
          }

          String linha = _limparLinha(linhaOCR.texto);

          if (linha.isEmpty) {
            continue;
          }

          // Ignora linhas de interface.
          if (_ehTextoIgnorado(linhaOCR.texto)) {
            continue;
          }

          if (_ehTextoIgnorado(linha)) {
            continue;
          }

          // Não deixa o título ficar enorme.
          if (partesNome.length >= 4) {
            break;
          }

          // Tamanho razoável para uma linha do título.
          if (linha.length < 3 || linha.length > 120) {
            continue;
          }

          partesNome.add(linha);
        }
      }

      // --------------------------------------------------------
      // FALLBACK
      //
      // Se por algum motivo não achou o preço, procura linhas
      // normais sem as palavras proibidas.
      // --------------------------------------------------------

      if (partesNome.isEmpty) {
        for (final linhaOCR in linhas) {
          String linha = _limparLinha(linhaOCR.texto);

          if (linha.isEmpty) {
            continue;
          }

          if (_ehTextoIgnorado(linhaOCR.texto)) {
            continue;
          }

          if (_ehTextoIgnorado(linha)) {
            continue;
          }

          if (linha.length < 5) {
            continue;
          }

          partesNome.add(linha);

          if (partesNome.length >= 3) {
            break;
          }
        }
      }

      // --------------------------------------------------------
      // MONTAR NOME
      // --------------------------------------------------------

      String nome = partesNome.join(' ');

      nome = _ajustarNomeProduto(nome);

      // Se o OCR ainda trouxe comissão escondida no meio,
      // faz uma última limpeza.
      nome = _limparLinha(nome);

      // --------------------------------------------------------
      // LIMITADOR DE SEGURANÇA
      //
      // Evita que o aplicativo copie uma quantidade enorme
      // de texto para o nome.
      // --------------------------------------------------------

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
  // COMPARTILHAR FOTO + DIVULGAÇÃO
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
  // COMPARTILHAR SOMENTE TEXTO
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
  // CAMPO DE LINK
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
  // CARD DAS INFORMAÇÕES
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
              fontWeight: FontWeight.w700,
              color: Color(0xFF171717),
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'PREÇO',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            _preco.isEmpty ? 'Preço não identificado' : _preco,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TEXTO DETECTADO
  // ============================================================

  Widget _textoDetectado() {
    return ExpansionTile(
      title: const Text(
        'Ver texto detectado no print',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w500,
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20,
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
            ),
          ),
          child: SelectableText(
            _textoLido.isEmpty
                ? 'Nenhum texto detectado.'
                : _textoLido,
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
  // BOTÃO LARANJA
  // ============================================================

  Widget _botaoPrincipal({
    required IconData icone,
    required String texto,
    required VoidCallback? aoClicar,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton.icon(
          onPressed: aoClicar,
          icon: Icon(
            icone,
            color: Colors.white,
            size: 28,
          ),
          label: Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            disabledBackgroundColor:
                Colors.deepOrange.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            elevation: 3,
          ),
        ),
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
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ------------------------------------------------
              // FOTO
              // ------------------------------------------------

              if (_imagem != null)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.20),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        color: const Color(0xFFFFF1EC),
                        child: const Text(
                          '✨ FOTO RECORTADA',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      Image.file(
                        _imagem!,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),

              // ------------------------------------------------
              // BOTÃO ESCOLHER PRINT
              // ------------------------------------------------

              const SizedBox(height: 18),

              _botaoPrincipal(
                icone: Icons.photo_library,
                texto: _imagem == null
                    ? 'ESCOLHER PRINT DA SHOPEE'
                    : 'ESCOLHER OUTRO PRINT',
                aoClicar: _carregando
                    ? null
                    : _escolherPrint,
              ),

              // ------------------------------------------------
              // CARREGANDO
              // ------------------------------------------------

              if (_carregando) ...[
                const SizedBox(height: 24),

                const CircularProgressIndicator(
                  color: Colors.deepOrange,
                ),

                const SizedBox(height: 12),

                const Text(
                  'Lendo o print...',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              // ------------------------------------------------
              // INFORMAÇÕES
              // ------------------------------------------------

              if (!_carregando && _imagem != null) ...[
                _cardInformacoes(),

                const SizedBox(height: 8),

                _textoDetectado(),

                const SizedBox(height: 8),

                _campoLink(),

                const SizedBox(height: 18),

                _botaoPrincipal(
                  icone: Icons.image,
                  texto: 'COMPARTILHAR FOTO + DIVULGAÇÃO',
                  aoClicar: _compartilharFoto,
                ),

                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: OutlinedButton.icon(
                      onPressed: _compartilharTexto,
                      icon: const Icon(
                        Icons.text_fields,
                        color: Colors.deepOrange,
                      ),
                      label: const Text(
                        'COMPARTILHAR SOMENTE TEXTO',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Colors.deepOrange,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
