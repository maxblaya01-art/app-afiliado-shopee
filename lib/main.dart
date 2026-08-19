import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
  final TextEditingController _linkController =
      TextEditingController();

  File? _imagem;

  String _nomeProduto = '';
  String _preco = '';
  String _textoLido = '';

  bool _carregando = false;
  bool _preparandoImagem = false;

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
  // OCR
  // ============================================================

  Future<void> _lerTextoDaImagem(String caminho) async {
    final TextRecognizer reconhecedor = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final InputImage imagem =
          InputImage.fromFilePath(caminho);

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

      // ==========================================================
      // ENCONTRAR PREÇO
      // ==========================================================

      final RegExp regexPreco = RegExp(
        r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
        caseSensitive: false,
      );

      for (final String linha in linhas) {
        final Match? match =
            regexPreco.firstMatch(linha);

        if (match != null) {
          preco = match.group(0) ?? '';

          if (preco.isNotEmpty) {
            break;
          }
        }
      }

      // ==========================================================
      // ENCONTRAR NOME DO PRODUTO
      // ==========================================================

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
        final String minuscula =
            linha.toLowerCase();

        final bool temPreco =
            regexPreco.hasMatch(linha);

        final bool ignorar =
            palavrasIgnoradas.any(
          (palavra) =>
              minuscula.contains(palavra),
        );

        if (!temPreco &&
            !ignorar &&
            linha.length >= 8 &&
            linha.length <= 150) {
          nome = linha;
          break;
        }
      }

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
  // PREPARAR IMAGEM
  //
  // Cria uma nova imagem:
  //
  // FOTO
  // ─────────────────
  // NOME DO PRODUTO
  // ─────────────────
  //
  // A imagem original é recortada para tentar manter somente
  // a região principal da foto do produto.
  // ============================================================

  Future<Uint8List?> _criarImagemDoProduto() async {
    if (_imagem == null) {
      return null;
    }

    try {
      final Uint8List bytes =
          await _imagem!.readAsBytes();

      final ui.Codec codec =
          await ui.instantiateImageCodec(bytes);

      final ui.FrameInfo frame =
          await codec.getNextFrame();

      final ui.Image imagemOriginal =
          frame.image;

      final int largura =
          imagemOriginal.width;

      final int altura =
          imagemOriginal.height;

      // ----------------------------------------------------------
      // Define uma área principal da imagem.
      //
      // Prints de lojas normalmente possuem a foto do produto
      // na região superior/central.
      // ----------------------------------------------------------

      int esquerda =
          (largura * 0.04).round();

      int topo =
          (altura * 0.08).round();

      int direita =
          (largura * 0.96).round();

      int baixo =
          (altura * 0.68).round();

      // Segurança para evitar valores inválidos.

      esquerda = esquerda.clamp(0, largura - 1);
      topo = topo.clamp(0, altura - 1);
      direita = direita.clamp(esquerda + 1, largura);
      baixo = baixo.clamp(topo + 1, altura);

      final int larguraCorte =
          direita - esquerda;

      final int alturaCorte =
          baixo - topo;

      // ----------------------------------------------------------
      // Tamanho da faixa verde.
      // ----------------------------------------------------------

      const double alturaFaixa = 115;

      final int larguraFinal =
          larguraCorte;

      final int alturaImagemFinal =
          alturaCorte + alturaFaixa.round();

      final ui.PictureRecorder recorder =
          ui.PictureRecorder();

      final Canvas canvas =
          Canvas(recorder);

      // Fundo branco.

      final Paint fundo =
          Paint()..color = Colors.white;

      canvas.drawRect(
        Rect.fromLTWH(
          0,
          0,
          larguraFinal.toDouble(),
          alturaImagemFinal.toDouble(),
        ),
        fundo,
      );

      // ----------------------------------------------------------
      // Desenhar a foto do produto.
      // ----------------------------------------------------------

      final Rect origem =
          Rect.fromLTWH(
        esquerda.toDouble(),
        topo.toDouble(),
        larguraCorte.toDouble(),
        alturaCorte.toDouble(),
      );

      final Rect destino =
          Rect.fromLTWH(
        0,
        0,
        larguraFinal.toDouble(),
        alturaCorte.toDouble(),
      );

      canvas.drawImageRect(
        imagemOriginal,
        origem,
        destino,
        Paint()
          ..filterQuality =
              FilterQuality.high,
      );

      // ----------------------------------------------------------
      // FAIXA VERDE
      // ----------------------------------------------------------

      final Paint faixa =
          Paint()
            ..color =
                const Color(0xFF087F3D);

      canvas.drawRect(
        Rect.fromLTWH(
          0,
          alturaCorte.toDouble(),
          larguraFinal.toDouble(),
          alturaFaixa,
        ),
        faixa,
      );

      // ----------------------------------------------------------
      // NOME DO PRODUTO
      // ----------------------------------------------------------

      String nome =
          _nomeProduto.trim();

      if (nome.isEmpty) {
        nome = 'Produto Shopee';
      }

      final double larguraTexto =
          larguraFinal - 32;

      final TextPainter texto =
          TextPainter(
        text: TextSpan(
          text: nome,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '...',
      );

      texto.layout(
        maxWidth: larguraTexto,
      );

      final double posicaoX =
          (larguraFinal - texto.width) / 2;

      final double posicaoY =
          alturaCorte +
              (alturaFaixa - texto.height) / 2;

      texto.paint(
        canvas,
        Offset(
          posicaoX,
          posicaoY,
        ),
      );

      // ----------------------------------------------------------
      // FINALIZAR IMAGEM
      // ----------------------------------------------------------

      final ui.Picture picture =
          recorder.endRecording();

      final ui.Image imagemFinal =
          await picture.toImage(
        larguraFinal,
        alturaImagemFinal,
      );

      final ByteData? dados =
          await imagemFinal.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (dados == null) {
        return null;
      }

      return dados.buffer.asUint8List();
    } catch (e) {
      debugPrint(
        'Erro ao criar imagem: $e',
      );

      return null;
    }
  }

  // ============================================================
  // COMPARTILHAR FOTO + TEXTO
  // ============================================================

  Future<void> _compartilhar() async {
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

    if (_preparandoImagem) {
      return;
    }

    setState(() {
      _preparandoImagem = true;
    });

    try {
      final Uint8List? imagemPronta =
          await _criarImagemDoProduto();

      if (imagemPronta == null) {
        if (mounted) {
          _mostrarMensagem(
            'Não foi possível preparar a imagem.',
          );
        }

        return;
      }

      final String texto =
          _gerarTextoDivulgacao();

      await SharePlus.instance.share(
        ShareParams(
          text: texto,
          subject:
              'Oferta Shopee - $_nomeProduto',
          files: [
            XFile.fromData(
              imagemPronta,
              name: 'produto_shopee.png',
              mimeType: 'image/png',
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensagem(
        'Não foi possível compartilhar.\n\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _preparandoImagem = false;
        });
      }
    }
  }

  // ============================================================
  // COMPARTILHAR SOMENTE TEXTO
  // ============================================================

  Future<void> _copiarTexto() async {
    final String link = _obterLink();

    if (link.isEmpty) {
      _mostrarMensagem(
        'Digite o seu link de afiliado primeiro.',
      );
      return;
    }

    final String texto =
        _gerarTextoDivulgacao();

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
      _preparandoImagem = false;
    });
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFFFF8F5),

      appBar: AppBar(
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor:
            Colors.deepOrange,
        foregroundColor: Colors.white,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(18),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,

            children: [

              // ==================================================
              // LINK
              // ==================================================

              TextField(
                controller:
                    _linkController,

                keyboardType:
                    TextInputType.url,

                decoration:
                    InputDecoration(
                  labelText:
                      'Link do produto / link de afiliado',

                  hintText:
                      'Cole seu link aqui',

                  prefixIcon:
                      const Icon(
                    Icons.link,
                  ),

                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),

                  filled: true,

                  fillColor:
                      Colors.white,
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              // ==================================================
              // BOTÃO PRINT
              // ==================================================

              ElevatedButton.icon(
                onPressed:
                    _carregando
                        ? null
                        : _escolherPrint,

                icon:
                    const Icon(
                  Icons.photo_library,
                ),

                label:
                    const Text(
                  'ESCOLHER FOTO / PRINT DO PRODUTO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                style:
                    ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 18,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              // ==================================================
              // CARREGANDO
              // ==================================================

              if (_carregando)
                const Card(
                  child: Padding(
                    padding:
                        EdgeInsets.all(20),

                    child: Column(
                      children: [

                        CircularProgressIndicator(),

                        SizedBox(
                          height: 12,
                        ),

                        Text(
                          'Lendo o nome e o preço do produto...',
                          textAlign:
                              TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              // ==================================================
              // FOTO DO PRODUTO
              // ==================================================

              if (_imagem != null &&
                  !_carregando)
                Card(
                  clipBehavior:
                      Clip.antiAlias,

                  child: Column(
                    children: [

                      const Padding(
                        padding:
                            EdgeInsets.all(12),

                        child: Row(
                          children: [

                            Icon(
                              Icons.image,
                              color:
                                  Colors.deepOrange,
                            ),

                            SizedBox(
                              width: 8,
                            ),

                            Text(
                              'FOTO DO PRODUTO',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Image.file(
                        _imagem!,
                        height: 300,
                        width:
                            double.infinity,
                        fit:
                            BoxFit.contain,
                      ),
                    ],
                  ),
                ),

              const SizedBox(
                height: 15,
              ),

              // ==================================================
              // RESULTADO
              // ==================================================

              if (!_carregando &&
                  (_nomeProduto
                          .isNotEmpty ||
                      _preco.isNotEmpty))
                Card(
                  elevation: 2,

                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      18,
                    ),

                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        const Text(
                          'INFORMAÇÕES ENCONTRADAS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Colors.grey,
                          ),
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        const Text(
                          'NOME DO PRODUTO',
                          style: TextStyle(
                            color:
                                Colors.grey,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          _nomeProduto
                                  .isEmpty
                              ? 'Não identificado'
                              : _nomeProduto,

                          style:
                              const TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        const Text(
                          'PREÇO',
                          style: TextStyle(
                            color:
                                Colors.grey,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          _preco.isEmpty
                              ? 'Não identificado'
                              : _preco,

                          style:
                              const TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ==================================================
              // TEXTO DETECTADO
              // ==================================================

              if (_textoLido
                  .isNotEmpty)
                ExpansionTile(
                  title:
                      const Text(
                    'Ver texto detectado no print',
                  ),

                  children: [

                    Padding(
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),

                      child:
                          SelectableText(
                        _textoLido,
                      ),
                    ),
                  ],
                ),

              const SizedBox(
                height: 12,
              ),

              // ==================================================
              // COMPARTILHAR FOTO + TEXTO
              // ==================================================

              if (_nomeProduto
                      .isNotEmpty ||
                  _preco.isNotEmpty)
                ElevatedButton.icon(
                  onPressed:
                      _preparandoImagem
                          ? null
                          : _compartilhar,

                  icon:
                      _preparandoImagem
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.image,
                            ),

                  label:
                      Text(
                    _preparandoImagem
                        ? 'PREPARANDO IMAGEM...'
                        : 'COMPARTILHAR FOTO + DIVULGAÇÃO',
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.deepOrange,

                    foregroundColor:
                        Colors.white,

                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 18,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                  ),
                ),

              const SizedBox(
                height: 10,
              ),

              // ==================================================
              // COMPARTILHAR SOMENTE TEXTO
              // ==================================================

              if (_nomeProduto
                      .isNotEmpty ||
                  _preco.isNotEmpty)
                OutlinedButton.icon(
                  onPressed:
                      _copiarTexto,

                  icon:
                      const Icon(
                    Icons.text_fields,
                  ),

                  label:
                      const Text(
                    'COMPARTILHAR SOMENTE TEXTO',
                  ),

                  style:
                      OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 15,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                  ),
                ),

              const SizedBox(
                height: 10,
              ),

              // ==================================================
              // LIMPAR
              // ==================================================

              if (_imagem != null)
                OutlinedButton.icon(
                  onPressed:
                      _limpar,

                  icon:
                      const Icon(
                    Icons.refresh,
                  ),

                  label:
                      const Text(
                    'LIMPAR',
                  ),

                  style:
                      OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 15,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                  ),
                ),

              const SizedBox(
                height: 20,
              ),

              const Text(
                'O aplicativo lê o nome e o preço visíveis no print '
                'e prepara uma imagem do produto com o nome em uma faixa verde.',

                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  color:
                      Colors.grey,
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
