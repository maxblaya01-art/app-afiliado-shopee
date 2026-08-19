import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_background_remover/image_background_remover.dart';
import 'package:image/image.dart' as img;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await BackgroundRemover.instance.initializeOrt();
  } catch (_) {}

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
  bool _compartilhando = false;

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
    final TextRecognizer reconhecedor =
        TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final InputImage imagem =
          InputImage.fromFilePath(caminho);

      final RecognizedText resultado =
          await reconhecedor.processImage(imagem);

      final String texto =
          resultado.text.trim();

      final List<String> linhas = texto
          .split('\n')
          .map((linha) => linha.trim())
          .where((linha) => linha.isNotEmpty)
          .toList();

      String nome = '';
      String preco = '';

      // ========================================================
      // ENCONTRAR PREÇO
      // ========================================================

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

      // ========================================================
      // PALAVRAS QUE NÃO DEVEM SER CONSIDERADAS
      // ========================================================

      final List<String> palavrasIgnoradas = [
        'shopee',
        'comprar',
        'oferta',
        'promoção',
        'promocao',
        'frete',
        'grátis',
        'gratis',
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
        'comissão extra',
        'comissao extra',
        'afiliados',
        'promoveram',
        'aprenda com outros criadores',
        'tecnologia',
        'tecnologia store',
        'favorite',
        'favoritar',
        'chat',
        'ganhar',
        'compartilhe',
        'compartilhe para ganhar',
        'confira aqui',
        'aproveite a oferta',
        'compartilhe para',
        'mil+ vendido',
        '1mil+ vendido',
      ];

      // ========================================================
      // LIMPAR LINHA
      // ========================================================

      String limparTexto(String texto) {
        return texto
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      // ========================================================
      // VERIFICAR SE PARECE NOME DE PRODUTO
      // ========================================================

      bool pareceNomeProduto(String linha) {
        final String minuscula =
            linha.toLowerCase();

        if (linha.length < 12) {
          return false;
        }

        if (linha.length > 180) {
          return false;
        }

        if (regexPreco.hasMatch(linha)) {
          return false;
        }

        for (final String palavra
            in palavrasIgnoradas) {
          if (minuscula.contains(palavra)) {
            return false;
          }
        }

        final RegExp temLetras =
            RegExp(r'[A-Za-zÀ-ÿ]');

        if (!temLetras.hasMatch(linha)) {
          return false;
        }

        return true;
      }

      // ========================================================
      // CRIAR CANDIDATOS
      // ========================================================

      final List<String> candidatos = [];

      for (int i = 0; i < linhas.length; i++) {
        final String atual =
            limparTexto(linhas[i]);

        if (pareceNomeProduto(atual)) {
          candidatos.add(atual);
        }

        // ------------------------------------------------------
        // DUAS LINHAS
        // ------------------------------------------------------

        if (i + 1 < linhas.length) {
          final String segunda =
              limparTexto(linhas[i + 1]);

          if (pareceNomeProduto(atual) &&
              pareceNomeProduto(segunda)) {
            final String combinado =
                '$atual $segunda';

            if (combinado.length <= 180) {
              candidatos.add(combinado);
            }
          }
        }

        // ------------------------------------------------------
        // TRÊS LINHAS
        // ------------------------------------------------------

        if (i + 2 < linhas.length) {
          final String segunda =
              limparTexto(linhas[i + 1]);

          final String terceira =
              limparTexto(linhas[i + 2]);

          if (pareceNomeProduto(atual) &&
              pareceNomeProduto(segunda) &&
              pareceNomeProduto(terceira)) {
            final String combinado =
                '$atual $segunda $terceira';

            if (combinado.length <= 180) {
              candidatos.add(combinado);
            }
          }
        }
      }

      // ========================================================
      // ESCOLHER MELHOR CANDIDATO
      // ========================================================

      int melhorPontuacao = -999999;

      for (final String candidato
          in candidatos) {
        final String minuscula =
            candidato.toLowerCase();

        int pontuacao = 0;

        // Títulos maiores recebem mais pontos.
        pontuacao += candidato.length;

        // Mais palavras normalmente significa
        // título mais completo.
        final int quantidadePalavras =
            candidato.split(' ').length;

        pontuacao += quantidadePalavras * 8;

        // ------------------------------------------------------
        // PALAVRAS CARACTERÍSTICAS DE PRODUTO
        // ------------------------------------------------------

        final List<String> palavrasProduto = [
          'produto',
          'cartão',
          'cartao',
          'memória',
          'memoria',
          'micro',
          'sd',
          'usb',
          'cabo',
          'carregador',
          'fone',
          'celular',
          'smart',
          'led',
          'controle',
          'adaptador',
          'velocidade',
          'alta',
          'gb',
          'tb',
          'hd',
          'ssd',
          'kit',
          'capa',
          'suporte',
        ];

        for (final String palavra
            in palavrasProduto) {
          if (minuscula.contains(palavra)) {
            pontuacao += 50;
          }
        }

        // Números costumam aparecer em especificações
        // de produtos.
        final int quantidadeNumeros =
            RegExp(r'\d+')
                .allMatches(candidato)
                .length;

        pontuacao += quantidadeNumeros * 15;

        if (pontuacao > melhorPontuacao) {
          melhorPontuacao = pontuacao;
          nome = candidato;
        }
      }

      // ========================================================
      // CORREÇÃO FINAL
      // ========================================================

      nome = nome
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (nome.isEmpty ||
          nome.toLowerCase() == 'tecnologia' ||
          nome.toLowerCase() == 'tecnologia store') {
        nome = 'Produto Shopee';
      }

      // ========================================================
      // RESULTADO
      // ========================================================

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
      link = 'https://$link';
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
  // CRIAR IMAGEM FINAL
  //
  // RESULTADO:
  //
  // ┌─────────────────────────────┐
  // │                             │
  // │       PRODUTO RECORTADO     │
  // │       FUNDO BRANCO          │
  // │                             │
  // ├─────────────────────────────┤
  // │ NOME DO PRODUTO             │
  // │ EM FAIXA VERDE              │
  // └─────────────────────────────┘
  //
  // ============================================================

  Future<File> _criarImagemFinal() async {
    if (_imagem == null) {
      throw Exception(
        'Nenhuma imagem foi selecionada.',
      );
    }

    // ----------------------------------------------------------
    // LER IMAGEM ORIGINAL
    // ----------------------------------------------------------

    final Uint8List bytesOriginais =
        await _imagem!.readAsBytes();

    // ----------------------------------------------------------
    // REMOVER FUNDO
    // ----------------------------------------------------------

    final ui.Image imagemSemFundo =
        await BackgroundRemover.instance.removeBg(
      bytesOriginais,
      threshold: 0.45,
      smoothMask: true,
      enhanceEdges: true,
    );

    // ----------------------------------------------------------
    // CONVERTER UI IMAGE PARA PNG
    // ----------------------------------------------------------

    final ByteData? dados =
        await imagemSemFundo.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (dados == null) {
      throw Exception(
        'Não foi possível processar a imagem.',
      );
    }

    final Uint8List pngSemFundo =
        dados.buffer.asUint8List();

    // ----------------------------------------------------------
    // DECODIFICAR
    // ----------------------------------------------------------

    final img.Image? imagemProcessada =
        img.decodeImage(pngSemFundo);

    if (imagemProcessada == null) {
      throw Exception(
        'Não foi possível decodificar a imagem.',
      );
    }

    // ----------------------------------------------------------
    // RECORTAR TODO O ESPAÇO TRANSPARENTE
    // ----------------------------------------------------------

    final img.Image produtoRecortado =
        img.trim(
      imagemProcessada,
      mode: img.TrimMode.transparent,
      padding: 25,
    );

    // ----------------------------------------------------------
    // CONVERTER NOVAMENTE PARA PNG
    // ----------------------------------------------------------

    final Uint8List produtoPng =
        Uint8List.fromList(
      img.encodePng(produtoRecortado),
    );

    // ----------------------------------------------------------
    // TRANSFORMAR EM UI IMAGE
    // ----------------------------------------------------------

    final ui.Codec codec =
        await ui.instantiateImageCodec(
      produtoPng,
    );

    final ui.FrameInfo frame =
        await codec.getNextFrame();

    final ui.Image produto =
        frame.image;

    // ----------------------------------------------------------
    // TAMANHO DA IMAGEM FINAL
    // ----------------------------------------------------------

    const double largura = 1080;

    const double alturaImagemProduto = 900;

    const double alturaFaixa = 330;

    const double alturaTotal =
        alturaImagemProduto + alturaFaixa;

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
          ..color = Colors.white;

    canvas.drawRect(
      const Rect.fromLTWH(
        0,
        0,
        largura,
        alturaTotal,
      ),
      fundoBranco,
    );

    // ----------------------------------------------------------
    // DESENHAR PRODUTO
    // ----------------------------------------------------------

    const double margem =
        45;

    final double areaLargura =
        largura - (margem * 2);

    final double areaAltura =
        alturaImagemProduto - (margem * 2);

    final double escalaX =
        areaLargura / produto.width;

    final double escalaY =
        areaAltura / produto.height;

    final double escala =
        escalaX < escalaY
            ? escalaX
            : escalaY;

    final double produtoLargura =
        produto.width * escala;

    final double produtoAltura =
        produto.height * escala;

    final double produtoX =
        (largura - produtoLargura) / 2;

    final double produtoY =
        (alturaImagemProduto -
                produtoAltura) /
            2;

    final Rect destinoProduto =
        Rect.fromLTWH(
      produtoX,
      produtoY,
      produtoLargura,
      produtoAltura,
    );

    final Paint paintProduto =
        Paint()
          ..filterQuality =
              FilterQuality.high;

    canvas.drawImageRect(
      produto,
      Rect.fromLTWH(
        0,
        0,
        produto.width.toDouble(),
        produto.height.toDouble(),
      ),
      destinoProduto,
      paintProduto,
    );

    // ----------------------------------------------------------
    // FAIXA VERDE
    // ----------------------------------------------------------

    final Paint faixaVerde =
        Paint()
          ..color =
              const Color(0xFF075E3D);

    canvas.drawRect(
      Rect.fromLTWH(
        0,
        alturaImagemProduto,
        largura,
        alturaFaixa,
      ),
      faixaVerde,
    );

    // ----------------------------------------------------------
    // NOME DO PRODUTO
    // ----------------------------------------------------------

    String nome =
        _nomeProduto.trim();

    if (nome.isEmpty) {
      nome = 'Produto Shopee';
    }

    final TextPainter textoPainter =
        TextPainter(
      text: TextSpan(
        text: nome,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 44,
          fontWeight: FontWeight.bold,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 4,
      ellipsis: '...',
    );

    textoPainter.layout(
      maxWidth: largura - 100,
    );

    final double textoX =
        (largura -
                textoPainter.width) /
            2;

    final double textoY =
        alturaImagemProduto +
        (alturaFaixa -
                textoPainter.height) /
            2;

    textoPainter.paint(
      canvas,
      Offset(
        textoX,
        textoY,
      ),
    );

    // ----------------------------------------------------------
    // FINALIZAR CANVAS
    // ----------------------------------------------------------

    final ui.Picture picture =
        recorder.endRecording();

    final ui.Image imagemFinal =
        await picture.toImage(
      largura.toInt(),
      alturaTotal.toInt(),
    );

    // ----------------------------------------------------------
    // CONVERTER PARA PNG
    // ----------------------------------------------------------

    final ByteData? bytesFinais =
        await imagemFinal.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (bytesFinais == null) {
      throw Exception(
        'Não foi possível criar a imagem final.',
      );
    }

    final Uint8List pngFinal =
        bytesFinais.buffer.asUint8List();

    // ----------------------------------------------------------
    // SALVAR TEMPORARIAMENTE
    // ----------------------------------------------------------

    final String nomeArquivo =
        'divulgacao_shopee_${DateTime.now().millisecondsSinceEpoch}.png';

    final File arquivoFinal =
        File(
      '${Directory.systemTemp.path}/$nomeArquivo',
    );

    await arquivoFinal.writeAsBytes(
      pngFinal,
      flush: true,
    );

    return arquivoFinal;
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

    if (_compartilhando) {
      return;
    }

    setState(() {
      _compartilhando = true;
    });

    try {
      _mostrarMensagem(
        'Preparando a imagem do produto...',
      );

      // --------------------------------------------------------
      // CRIAR IMAGEM RECORTADA
      // --------------------------------------------------------

      final File imagemFinal =
          await _criarImagemFinal();

      // --------------------------------------------------------
      // TEXTO
      // --------------------------------------------------------

      final String texto =
          _gerarTextoDivulgacao();

      // --------------------------------------------------------
      // COMPARTILHAR
      // --------------------------------------------------------

      await SharePlus.instance.share(
        ShareParams(
          text: texto,
          subject:
              'Oferta Shopee - $_nomeProduto',
          files: [
            XFile(
              imagemFinal.path,
              mimeType: 'image/png',
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensagem(
        'Não foi possível criar a divulgação.\n\n$e',
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _compartilhando = false;
      });
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
    });
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _mostrarMensagem(
    String mensagem,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
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
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor:
            Colors.deepOrange,
        foregroundColor:
            Colors.white,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(18),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,

            children: [

              // =================================================
              // LINK
              // =================================================

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

              // =================================================
              // ESCOLHER PRINT
              // =================================================

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

              // =================================================
              // CARREGANDO
              // =================================================

              if (_carregando)
                const Card(
                  child:
                      Padding(
                    padding:
                        EdgeInsets.all(20),

                    child:
                        Column(
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

              // =================================================
              // FOTO ORIGINAL
              // =================================================

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
                            EdgeInsets.all(12),

                        child:
                            Row(
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
                              'PRINT ORIGINAL',
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

              // =================================================
              // RESULTADO OCR
              // =================================================

              if (!_carregando &&
                  (_nomeProduto
                          .isNotEmpty ||
                      _preco.isNotEmpty))
                Card(
                  elevation: 2,

                  child:
                      Padding(
                    padding:
                        const EdgeInsets.all(
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
                          style:
                              TextStyle(
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
                            fontSize: 19,
                            fontWeight:
                                FontWeight.bold,
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

              // =================================================
              // TEXTO DETECTADO
              // =================================================

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

              // =================================================
              // COMPARTILHAR
              // =================================================

              if (_nomeProduto
                      .isNotEmpty ||
                  _preco.isNotEmpty)
                ElevatedButton.icon(
                  onPressed:
                      _compartilhando
                          ? null
                          : _compartilhar,

                  icon:
                      _compartilhando
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
                    _compartilhando
                        ? 'CRIANDO IMAGEM...'
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

              // =================================================
              // SOMENTE TEXTO
              // =================================================

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

              // =================================================
              // LIMPAR
              // =================================================

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
                'O aplicativo identifica o nome e o preço '
                'do produto, remove o fundo da imagem e '
                'cria uma nova imagem pronta para divulgação.',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
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
