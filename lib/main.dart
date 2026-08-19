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
  // ESCOLHER PRINT DA GALERIA
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
  // OCR - LER TEXTO DO PRINT
  // ============================================================

  Future<void> _lerTextoDaImagem(String caminho) async {
    final TextRecognizer reconhecedor = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final InputImage imagem = InputImage.fromFilePath(caminho);

      final RecognizedText resultado =
          await reconhecedor.processImage(imagem);

      final String texto = resultado.text.trim();

      final List<String> linhas = texto
          .split('\n')
          .map((linha) => linha.trim())
          .where((linha) => linha.isNotEmpty)
          .toList();

      String nome = '';
      String preco = '';

      // ----------------------------------------------------------
      // TENTA ENCONTRAR UM PREÇO
      // ----------------------------------------------------------

      final RegExp regexPreco = RegExp(
        r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
        caseSensitive: false,
      );

      for (final String linha in linhas) {
        final Match? match = regexPreco.firstMatch(linha);

        if (match != null) {
          preco = match.group(0) ?? '';

          if (preco.isNotEmpty) {
            break;
          }
        }
      }

      // ----------------------------------------------------------
      // TENTA ENCONTRAR O NOME DO PRODUTO
      // ----------------------------------------------------------

      final List<String> palavrasIgnoradas = [
        'shopee',
        'comprar',
        'oferta',
        'promoção',
        'promocao',
        'frete grátis',
        'frete gratis',
        'cupom',
        'avaliações',
        'avaliacoes',
        'vendido',
        'parcelado',
        'entrega',
        'compartilhar',
        'adicionar ao carrinho',
        'comprar agora',
      ];

      for (final String linha in linhas) {
        final String minuscula = linha.toLowerCase();

        final bool temPreco = regexPreco.hasMatch(linha);

        final bool ignorar = palavrasIgnoradas.any(
          (palavra) => minuscula.contains(palavra),
        );

        if (!temPreco &&
            !ignorar &&
            linha.length >= 8 &&
            linha.length <= 150) {
          nome = linha;
          break;
        }
      }

      // Se não encontrou um nome, pega uma das primeiras linhas.
      if (nome.isEmpty && linhas.isNotEmpty) {
        nome = linhas.first;
      }

      if (!mounted) return;

      setState(() {
        _textoLido = texto;
        _nomeProduto = nome;
        _preco = preco;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

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
  // GERAR TEXTO DA DIVULGAÇÃO
  // ============================================================

  String _gerarTextoDivulgacao() {
    final String nome = _nomeProduto.isEmpty
        ? 'Produto Shopee'
        : _nomeProduto;

    final String preco = _preco.isEmpty
        ? 'Confira o preço'
        : _preco;

    final String link = _obterLink();

    String texto = '''
🔥 OFERTA NA SHOPEE 🔥

🛍️ $nome

💰 $preco

👇 Confira aqui:
$link

🛒 Aproveite a oferta!
''';

    return texto.trim();
  }

  // ============================================================
  // COMPARTILHAR
  // ============================================================

  Future<void> _compartilhar() async {
    final String link = _obterLink();

    if (link.isEmpty) {
      _mostrarMensagem(
        'Digite o seu link de afiliado antes de compartilhar.',
      );
      return;
    }

    final String texto = _gerarTextoDivulgacao();

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: texto,
          subject: 'Oferta Shopee',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensagem(
        'Não foi possível abrir o compartilhamento.\n\n$e',
      );
    }
  }

  // ============================================================
  // COPIAR TEXTO
  // ============================================================

  Future<void> _copiarTexto() async {
    final String link = _obterLink();

    if (link.isEmpty) {
      _mostrarMensagem(
        'Digite o seu link de afiliado primeiro.',
      );
      return;
    }

    final String texto = _gerarTextoDivulgacao();

    await SharePlus.instance.share(
      ShareParams(
        text: texto,
      ),
    );
  }

  // ============================================================
  // LIMPAR
  // ============================================================

  void _limpar() {
    setState(() {
      _imagem = null;
      _nomeProduto = '';
      _preco = '';
      _textoLido = '';
      _linkController.clear();
    });
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --------------------------------------------------
              // LINK
              // --------------------------------------------------

              TextField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Link do produto / link de afiliado',
                  hintText: 'Cole seu link aqui',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 14),

              // --------------------------------------------------
              // BOTÃO PRINT
              // --------------------------------------------------

              ElevatedButton.icon(
                onPressed:
                    _carregando ? null : _escolherPrint,
                icon: const Icon(Icons.photo_library),
                label: const Text(
                  'ESCOLHER PRINT DO PRODUTO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // --------------------------------------------------
              // CARREGANDO
              // --------------------------------------------------

              if (_carregando)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text(
                          'Lendo as informações do print...',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              // --------------------------------------------------
              // IMAGEM
              // --------------------------------------------------

              if (_imagem != null && !_carregando)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(
                    _imagem!,
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                ),

              const SizedBox(height: 15),

              // --------------------------------------------------
              // RESULTADO
              // --------------------------------------------------

              if (!_carregando &&
                  (_nomeProduto.isNotEmpty ||
                      _preco.isNotEmpty))
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'INFORMAÇÕES ENCONTRADAS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 15),

                        const Text(
                          'PRODUTO',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          _nomeProduto.isEmpty
                              ? 'Não identificado'
                              : _nomeProduto,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 18),

                        const Text(
                          'PREÇO',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          _preco.isEmpty
                              ? 'Não identificado'
                              : _preco,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // --------------------------------------------------
              // TEXTO DETECTADO
              // --------------------------------------------------

              if (_textoLido.isNotEmpty)
                ExpansionTile(
                  title: const Text(
                    'Ver texto detectado no print',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        _textoLido,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              // --------------------------------------------------
              // COMPARTILHAR
              // --------------------------------------------------

              if (_nomeProduto.isNotEmpty ||
                  _preco.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _compartilhar,
                  icon: const Icon(Icons.share),
                  label: const Text(
                    'COMPARTILHAR DIVULGAÇÃO',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              // --------------------------------------------------
              // LIMPAR
              // --------------------------------------------------

              if (_imagem != null)
                OutlinedButton.icon(
                  onPressed: _limpar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('LIMPAR'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              const Text(
                'O aplicativo lê as informações visíveis no print. '
                'O link de afiliado é informado manualmente por você.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
