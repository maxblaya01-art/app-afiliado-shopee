import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_background_remover/image_background_remover.dart';

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
  void initState() {
    super.initState();

    _inicializarRemovedor();
  }

  Future<void> _inicializarRemovedor() async {
    try {
      await BackgroundRemover.instance.initializeOrt();
    } catch (e) {
      debugPrint(
        'Erro ao inicializar removedor de fundo: $e',
      );
    }
  }

  @override
  void dispose() {
    _linkController.dispose();

    BackgroundRemover.instance.dispose();

    super.dispose();
  }

  // ============================================================
  // ESCOLHER PRINT
  // ============================================================

  Future<void> _escolherPrint() async {
    try {
      final XFile? arquivo =
          await _picker.pickImage(
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

      await _lerTextoDaImagem(
        arquivo.path,
      );
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

  Future<void> _lerTextoDaImagem(
    String caminho,
  ) async {
    final TextRecognizer reconhecedor =
        TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final InputImage imagem =
          InputImage.fromFilePath(caminho);

      final RecognizedText resultado =
          await reconhecedor.processImage(
        imagem,
      );

      final String texto =
          resultado.text.trim();

      final List<String> linhas = texto
          .split('\n')
          .map(
            (linha) => linha.trim(),
          )
          .where(
            (linha) => linha.isNotEmpty,
          )
          .toList();

      String nome = '';
      String preco = '';

      // ==========================================================
      // ENCONTRAR PREÇO
      // ==========================================================

      final RegExp regexPreco =
          RegExp(
        r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
        caseSensitive: false,
      );

      for (final String linha in linhas) {
        final Match? match =
            regexPreco.firstMatch(linha);

        if (match != null) {
          preco =
              match.group(0) ?? '';

          if (preco.isNotEmpty) {
            break;
          }
        }
      }

      // ==========================================================
      // PALAVRAS QUE NÃO SÃO NOME DO PRODUTO
      // ==========================================================

      final List<String>
          palavrasIgnoradas = [
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
        'variações',
        'variacoes',
        'comissão',
        'comissao',
        'afiliados',
        'mil+ vendido',
        'mil vendido',
        'comissão extra',
        'comissao extra',
      ];

      // ==========================================================
      // ENCONTRAR NOME DO PRODUTO
      // ==========================================================

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
            linha.length <= 180) {
          nome = linha;
          break;
        }
      }

      if (nome.isEmpty &&
          linhas.isNotEmpty) {
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
    String link =
        _linkController.text.trim();

    if (link.isEmpty) {
      return '';
    }

    if (!link.startsWith('http://') &&
        !link.startsWith('https://')) {
      link =
          'https://$link';
    }

    return link;
  }

  // ============================================================
  // TEXTO DA DIVULGAÇÃO
  // ============================================================

  String _gerarTextoDivulgacao() {
    final String nome =
        _nomeProduto.isEmpty
            ? 'Produto Shopee'
            : _nomeProduto;

    final String preco =
        _preco.isEmpty
            ? 'Confira o preço'
            : _preco;

    final String link =
        _obterLink();

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
  // RECORTAR A FOTO PRINCIPAL DO PRINT
  // ============================================================

  Future<ui.Image?>
      _recortarFotoPrincipal(
    Uint8List bytes,
  ) async {
    final ui.Codec codec =
        await ui.instantiateImageCodec(
      bytes,
    );

    final ui.FrameInfo frame =
        await codec.getNextFrame();

    final ui.Image original =
        frame.image;

    final int largura =
        original.width;

    final int altura =
        original.height;

    // Para o formato do seu print:
    //
    // esquerda = começa a foto principal
    // topo = começo da foto
    // direita = lado direito da foto
    // baixo = termina antes das variações

    int esquerda =
        (largura * 0.30).round();

    int topo =
        (altura * 0.02).round();

    int direita =
        (largura * 0.96).round();

    int baixo =
        (altura * 0.32).round();

    esquerda =
        esquerda.clamp(
      0,
      largura - 1,
    );

    topo =
        topo.clamp(
      0,
      altura - 1,
    );

    direita =
        direita.clamp(
      esquerda + 1,
      largura,
    );

    baixo =
        baixo.clamp(
      topo + 1,
      altura,
    );

    final int larguraCorte =
        direita - esquerda;

    final int alturaCorte =
        baixo - topo;

    final ui.PictureRecorder recorder =
        ui.PictureRecorder();

    final Canvas canvas =
        Canvas(recorder);

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
      larguraCorte.toDouble(),
      alturaCorte.toDouble(),
    );

    canvas.drawImageRect(
      original,
      origem,
      destino,
      Paint()
        ..filterQuality =
            FilterQuality.high,
    );

    final ui.Picture picture =
        recorder.endRecording();

    final ui.Image recortada =
        await picture.toImage(
      larguraCorte,
      alturaCorte,
    );

    return recortada;
  }

  // ============================================================
  // CONVERTER UI.IMAGE PARA PNG
  // ============================================================

  Future<Uint8List?>
      _imagemParaPng(
    ui.Image imagem,
  ) async {
    final ByteData? dados =
        await imagem.toByteData(
      format:
          ui.ImageByteFormat.png,
    );

    if (dados == null) {
      return null;
    }

    return dados.buffer
        .asUint8List();
  }

  // ============================================================
  // ENCONTRAR LIMITES DO PRODUTO
  //
  // Depois de remover o fundo, procura somente a região
  // realmente ocupada pelo produto.
  // ============================================================

  Future<ui.Image>
      _recortarAreaTransparente(
    ui.Image imagem,
  ) async {
    final ByteData? dados =
        await imagem.toByteData(
      format:
          ui.ImageByteFormat.rawRgba,
    );

    if (dados == null) {
      return imagem;
    }

    final Uint8List pixels =
        dados.buffer.asUint8List();

    final int largura =
        imagem.width;

    final int altura =
        imagem.height;

    int minX = largura;
    int minY = altura;
    int maxX = -1;
    int maxY = -1;

    for (int y = 0;
        y < altura;
        y++) {
      for (int x = 0;
          x < largura;
          x++) {
        final int indice =
            (y * largura + x) * 4;

        final int alpha =
            pixels[indice + 3];

        if (alpha > 20) {
          if (x < minX) {
            minX = x;
          }

          if (y < minY) {
            minY = y;
          }

          if (x > maxX) {
            maxX = x;
          }

          if (y > maxY) {
            maxY = y;
          }
        }
      }
    }

    if (maxX < 0 ||
        maxY < 0) {
      return imagem;
    }

    const int margem = 15;

    minX =
        (minX - margem)
            .clamp(
      0,
      largura - 1,
    );

    minY =
        (minY - margem)
            .clamp(
      0,
      altura - 1,
    );

    maxX =
        (maxX + margem)
            .clamp(
      0,
      largura - 1,
    );

    maxY =
        (maxY + margem)
            .clamp(
      0,
      altura - 1,
    );

    final int larguraFinal =
        maxX - minX + 1;

    final int alturaFinal =
        maxY - minY + 1;

    final ui.PictureRecorder recorder =
        ui.PictureRecorder();

    final Canvas canvas =
        Canvas(recorder);

    final Rect origem =
        Rect.fromLTWH(
      minX.toDouble(),
      minY.toDouble(),
      larguraFinal.toDouble(),
      alturaFinal.toDouble(),
    );

    final Rect destino =
        Rect.fromLTWH(
      0,
      0,
      larguraFinal.toDouble(),
      alturaFinal.toDouble(),
    );

    canvas.drawImageRect(
      imagem,
      origem,
      destino,
      Paint()
        ..filterQuality =
            FilterQuality.high,
    );

    final ui.Picture picture =
        recorder.endRecording();

    return picture.toImage(
      larguraFinal,
      alturaFinal,
    );
  }

  // ============================================================
  // CRIAR IMAGEM FINAL
  //
  // 1. Recorta foto
  // 2. Remove fundo
  // 3. Coloca fundo branco
  // 4. Coloca faixa verde
  // 5. Coloca nome
  // ============================================================

  Future<Uint8List?>
      _criarImagemDoProduto() async {
    if (_imagem == null) {
      return null;
    }

    try {
      final Uint8List originalBytes =
          await _imagem!.readAsBytes();

      // ----------------------------------------------------------
      // RECORTAR FOTO PRINCIPAL
      // ----------------------------------------------------------

      final ui.Image? fotoRecortada =
          await _recortarFotoPrincipal(
        originalBytes,
      );

      if (fotoRecortada == null) {
        return null;
      }

      final Uint8List? fotoPng =
          await _imagemParaPng(
        fotoRecortada,
      );

      if (fotoPng == null) {
        return null;
      }

      // ----------------------------------------------------------
      // REMOVER FUNDO
      // ----------------------------------------------------------

      final ui.Image produtoSemFundo =
          await BackgroundRemover
              .instance
              .removeBg(
        fotoPng,
        threshold: 0.50,
        smoothMask: true,
        enhanceEdges: true,
      );

      // ----------------------------------------------------------
      // CORTAR SOBRAS TRANSPARENTES
      // ----------------------------------------------------------

      final ui.Image produto =
          await _recortarAreaTransparente(
        produtoSemFundo,
      );

      // ----------------------------------------------------------
      // TAMANHO DA IMAGEM FINAL
      // ----------------------------------------------------------

      final int largura =
          produto.width;

      final double proporcao =
          largura > 0
              ? produto.height /
                  largura
              : 1.0;

      final int alturaProduto =
          (largura * proporcao)
              .round();

      const int alturaFaixa =
          145;

      final int alturaTotal =
          alturaProduto +
              alturaFaixa;

      // ----------------------------------------------------------
      // CRIAR CANVAS
      // ----------------------------------------------------------

      final ui.PictureRecorder recorder =
          ui.PictureRecorder();

      final Canvas canvas =
          Canvas(recorder);

      // ----------------------------------------------------------
      // FUNDO BRANCO
      // ----------------------------------------------------------

      final Paint fundoBranco =
          Paint()
            ..color =
                Colors.white;

      canvas.drawRect(
        Rect.fromLTWH(
          0,
          0,
          largura.toDouble(),
          alturaTotal.toDouble(),
        ),
        fundoBranco,
      );

      // ----------------------------------------------------------
      // PRODUTO
      // ----------------------------------------------------------

      final Rect origem =
          Rect.fromLTWH(
        0,
        0,
        produto.width.toDouble(),
        produto.height.toDouble(),
      );

      final Rect destino =
          Rect.fromLTWH(
        0,
        0,
        largura.toDouble(),
        alturaProduto.toDouble(),
      );

      canvas.drawImageRect(
        produto,
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
                const Color(0xFF075F3B);

      canvas.drawRect(
        Rect.fromLTWH(
          0,
          alturaProduto.toDouble(),
          largura.toDouble(),
          alturaFaixa.toDouble(),
        ),
        faixa,
      );

      // ----------------------------------------------------------
      // NOME
      // ----------------------------------------------------------

      String nome =
          _nomeProduto.trim();

      if (nome.isEmpty) {
        nome =
            'Produto Shopee';
      }

      final TextPainter texto =
          TextPainter(
        text: TextSpan(
          text: nome,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight:
                FontWeight.bold,
            height: 1.12,
          ),
        ),
        textAlign:
            TextAlign.center,
        textDirection:
            TextDirection.ltr,
        maxLines: 4,
        ellipsis: '...',
      );

      texto.layout(
        maxWidth:
            largura - 36,
      );

      final double x =
          (largura - texto.width) /
              2;

      final double y =
          alturaProduto +
              (alturaFaixa -
                      texto.height) /
                  2;

      texto.paint(
        canvas,
        Offset(x, y),
      );

      // ----------------------------------------------------------
      // FINALIZAR
      // ----------------------------------------------------------

      final ui.Picture picture =
          recorder.endRecording();

      final ui.Image imagemFinal =
          await picture.toImage(
        largura,
        alturaTotal,
      );

      return _imagemParaPng(
        imagemFinal,
      );
    } catch (e) {
      debugPrint(
        'Erro ao criar imagem final: $e',
      );

      return null;
    }
  }

  // ============================================================
  // COMPARTILHAR FOTO + TEXTO
  // ============================================================

  Future<void> _compartilhar() async {
    final String link =
        _obterLink();

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
              name:
                  'produto_shopee.png',
              mimeType:
                  'image/png',
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
    final String link =
        _obterLink();

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

  void _mostrarMensagem(
    String mensagem,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(mensagem),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFFFF8F5),

      appBar: AppBar(
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor:
            Colors.deepOrange,
        foregroundColor:
            Colors.white,
      ),

      body: SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.all(
            18,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,

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
                        BorderRadius
                            .circular(
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
              // BOTÃO FOTO
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
                      const EdgeInsets
                          .symmetric(
                    vertical: 18,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      18,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              // ==================================================
              // CARREGANDO OCR
              // ==================================================

              if (_carregando)
                const Card(
                  child:
                      Padding(
                    padding:
                        EdgeInsets.all(
                      20,
                    ),

                    child: Column(
                      children: [

                        CircularProgressIndicator(),

                        SizedBox(
                          height: 12,
                        ),

                        Text(
                          'Lendo o nome e o preço do produto...',
                          textAlign:
                              TextAlign
                                  .center,
                        ),
                      ],
                    ),
                  ),
                ),

              // ==================================================
              // FOTO ORIGINAL
              // ==================================================

              if (_imagem != null &&
                  !_carregando)
                Card(
                  clipBehavior:
                      Clip.antiAlias,

                  child:
                      Column(
                    children: [

                      const Padding(
                        padding:
                            EdgeInsets
                                .all(
                          12,
                        ),

                        child:
                            Row(
                          children: [

                            Icon(
                              Icons.image,
                              color:
                                  Colors
                                      .deepOrange,
                            ),

                            SizedBox(
                              width: 8,
                            ),

                            Text(
                              'FOTO DO PRODUTO',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
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
              // INFORMAÇÕES
              // ==================================================

              if (!_carregando &&
                  (_nomeProduto
                          .isNotEmpty ||
                      _preco
                          .isNotEmpty))
                Card(
                  elevation: 2,

                  child:
                      Padding(
                    padding:
                        const EdgeInsets
                            .all(
                      18,
                    ),

                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [

                        const Text(
                          'INFORMAÇÕES ENCONTRADAS',
                          style:
                              TextStyle(
                            fontSize:
                                14,
                            fontWeight:
                                FontWeight
                                    .bold,
                            color:
                                Colors
                                    .grey,
                          ),
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        const Text(
                          'NOME DO PRODUTO',
                          style:
                              TextStyle(
                            color:
                                Colors
                                    .grey,
                            fontWeight:
                                FontWeight
                                    .bold,
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
                            fontSize:
                                20,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        const Text(
                          'PREÇO',
                          style:
                              TextStyle(
                            color:
                                Colors
                                    .grey,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          _preco
                                  .isEmpty
                              ? 'Não identificado'
                              : _preco,

                          style:
                              const TextStyle(
                            fontSize:
                                22,
                            fontWeight:
                                FontWeight
                                    .bold,
                            color:
                                Colors
                                    .deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ==================================================
              // TEXTO OCR
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
                          const EdgeInsets
                              .all(
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
              // COMPARTILHAR
              // ==================================================

              if (_nomeProduto
                      .isNotEmpty ||
                  _preco
                      .isNotEmpty)
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
                                strokeWidth:
                                    2,
                                color:
                                    Colors
                                        .white,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .share,
                            ),

                  label:
                      Text(
                    _preparandoImagem
                        ? 'PREPARANDO PRODUTO...'
                        : 'COMPARTILHAR FOTO + DIVULGAÇÃO',

                    style:
                        const TextStyle(
                      fontSize:
                          16,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),

                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Colors
                            .deepOrange,

                    foregroundColor:
                        Colors.white,

                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 18,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),
                    ),
                  ),
                ),

              const SizedBox(
                height: 10,
              ),

              // ==================================================
              // TEXTO
              // ==================================================

              if (_nomeProduto
                      .isNotEmpty ||
                  _preco
                      .isNotEmpty)
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
                      OutlinedButton
                          .styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 15,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
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
                      OutlinedButton
                          .styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 15,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),
                    ),
                  ),
                ),

              const SizedBox(
                height: 20,
              ),

              const Text(
                'O aplicativo identifica o produto, remove o fundo '
                'da imagem e prepara uma divulgação pronta para compartilhar.',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      Colors.grey,
                  fontSize:
                      13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
