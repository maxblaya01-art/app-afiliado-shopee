import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
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

  File? _imagemOriginal;
  File? _imagemRecortada;

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
        _imagemOriginal = File(arquivo.path);
        _imagemRecortada = null;
        _nomeProduto = '';
        _preco = '';
        _textoLido = '';
        _carregando = true;
      });

      await _lerTextoDaImagem(arquivo.path);

      final File? recortada =
          await _recortarFotoPrincipal(arquivo.path);

      if (!mounted) return;

      setState(() {
        _imagemRecortada = recortada;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
      });

      _mostrarMensagem(
        'Não foi possível processar o print.\n\n$e',
      );
    }
  }

  // ============================================================
  // RECORTAR FOTO PRINCIPAL
  // ============================================================

  Future<File?> _recortarFotoPrincipal(String caminho) async {
    try {
      final File arquivo = File(caminho);

      final Uint8List bytes =
          await arquivo.readAsBytes();

      final img.Image? original =
          img.decodeImage(bytes);

      if (original == null) {
        return null;
      }

      final int largura = original.width;
      final int altura = original.height;

      final int topo =
          (altura * 0.035).round();

      final int finalFoto =
          (altura * 0.46).round();

      int alturaRecorte =
          finalFoto - topo;

      if (alturaRecorte < 100) {
        alturaRecorte = altura - topo;
      }

      final int margemHorizontal =
          (largura * 0.015).round();

      final int x = margemHorizontal;
      final int y = topo;

      final int larguraRecorte =
          largura - (margemHorizontal * 2);

      final int larguraFinal =
          larguraRecorte.clamp(
        1,
        largura - x,
      ).toInt();

      final int alturaFinal =
          alturaRecorte.clamp(
        1,
        altura - y,
      ).toInt();

      final img.Image recorte =
          img.copyCrop(
        original,
        x: x,
        y: y,
        width: larguraFinal,
        height: alturaFinal,
      );

      final List<int> jpg =
          img.encodeJpg(
        recorte,
        quality: 95,
      );

      final String novoCaminho =
          '${Directory.systemTemp.path}/produto_recortado_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final File novoArquivo =
          File(novoCaminho);

      await novoArquivo.writeAsBytes(jpg);

      return novoArquivo;
    } catch (e) {
      return null;
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
          .map(
            (linha) => linha.trim(),
          )
          .where(
            (linha) => linha.isNotEmpty,
          )
          .toList();

      String preco = '';

      // ==========================================================
      // PREÇO
      // ==========================================================

      final RegExp regexPreco = RegExp(
        r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
        caseSensitive: false,
      );

      int indicePreco = -1;

      for (int i = 0; i < linhas.length; i++) {
        final Match? match =
            regexPreco.firstMatch(linhas[i]);

        if (match != null) {
          preco = match.group(0) ?? '';
          indicePreco = i;

          final String linhaMinuscula =
              linhas[i].toLowerCase();

          if (linhaMinuscula.contains('r\$')) {
            break;
          }
        }
      }

      // ==========================================================
      // FUNÇÃO PARA IDENTIFICAR TEXTO QUE NÃO É PRODUTO
      // ==========================================================

      bool linhaEhLixo(String linha) {
        final String t =
            linha.toLowerCase().trim();

        // Comissão
        if (t.contains('comissão extra') ||
            t.contains('comissao extra') ||
            t.contains('comissãoextra') ||
            t.contains('comissaoextra') ||
            t == 'comissão' ||
            t == 'comissao') {
          return true;
        }

        // Porcentagem
        if (RegExp(
          r'\d+[,.]?\d*\s*%',
        ).hasMatch(t)) {
          return true;
        }

        // Preço
        if (regexPreco.hasMatch(t)) {
          return true;
        }

        // Elementos da interface
        final List<String> ignorar = [
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
          'avaliação',
          'avaliacao',
          'vendido',
          'parcelado',
          'entrega',
          'compartilhar',
          'adicionar ao carrinho',
          'comprar agora',
          'chat',
          'favoritar',
          'aprenda com outros criadores',
          'compartilhe para ganhar',
          'afiliados promoveram',
          'afiliados',
          'criadores',
          'mais vendidos',
          'mais vendido',
          'vendas',
          'computadores e acessórios',
          'computadores',
          'acessórios para',
          'acessorios para',
          'shopee live',
          'estrelas',
          'visitar',
          'loja oficial',
          'oficial store',
          'no.',
          'no ',
        ];

        for (final String palavra in ignorar) {
          if (t.contains(palavra)) {
            return true;
          }
        }

        // Linhas que começam com "No.11", "No. 11" etc.
        if (RegExp(
          r'^no\.?\s*\d+',
          caseSensitive: false,
        ).hasMatch(t)) {
          return true;
        }

        // Horário do celular
        if (RegExp(
          r'^\d{1,2}:\d{2}$',
        ).hasMatch(t)) {
          return true;
        }

        // Textos muito pequenos
        if (t.length < 4) {
          return true;
        }

        return false;
      }

      // ==========================================================
      // ENCONTRAR NOME DO PRODUTO
      //
      // A Shopee geralmente coloca:
      //
      // R$ 397,00   COMISSÃO EXTRA 4,5%
      // Projetor VEVSHAO A12 Android 13...
      // Suporte 4K, WiFi 6...
      //
      // O código abaixo procura várias linhas consecutivas
      // depois do preço e junta tudo.
      // ==========================================================

      String nome = '';

      if (indicePreco >= 0) {
        final List<String> partesNome = [];

        int linhasIgnoradasDepoisPreco = 0;

        for (
          int i = indicePreco + 1;
          i < linhas.length && i <= indicePreco + 12;
          i++
        ) {
          final String linha =
              linhas[i].trim();

          final String minuscula =
              linha.toLowerCase();

          // Parar quando chegou na parte inferior
          // da página do produto.
          if (minuscula.contains(
                'aprenda com outros criadores',
              ) ||
              minuscula.contains(
                'afiliados promoveram',
              ) ||
              minuscula.contains(
                'vendido',
              ) ||
              minuscula.contains(
                'avaliações',
              ) ||
              minuscula.contains(
                'avaliacoes',
              ) ||
              minuscula.contains(
                'estrelas',
              )) {
            break;
          }

          // Comissão / porcentagem / elementos da interface.
          if (linhaEhLixo(linha)) {
            linhasIgnoradasDepoisPreco++;

            // Algumas vezes a comissão aparece em
            // mais de uma linha. Continuamos procurando.
            if (linhasIgnoradasDepoisPreco <= 4) {
              continue;
            }

            break;
          }

          // Não aceitar textos enormes de interface.
          if (linha.length > 220) {
            continue;
          }

          partesNome.add(linha);

          // Produtos grandes podem ter 2, 3 ou até 4 linhas.
          if (partesNome.length >= 4) {
            break;
          }
        }

        if (partesNome.isNotEmpty) {
          nome = partesNome.join(' ');
        }
      }

      // ==========================================================
      // SEGUNDA TENTATIVA
      //
      // Se o OCR colocou a primeira parte do título antes
      // do preço, procuramos candidatos em todo o texto.
      // ==========================================================

      if (nome.isEmpty) {
        final List<String> candidatos = [];

        for (final String linha in linhas) {
          if (linhaEhLixo(linha)) {
            continue;
          }

          candidatos.add(linha);
        }

        if (candidatos.isNotEmpty) {
          // Preferimos linhas que tenham características
          // de título de produto.
          candidatos.sort(
            (a, b) {
              final int pontuacaoA =
                  _pontuarLinhaProduto(a);

              final int pontuacaoB =
                  _pontuarLinhaProduto(b);

              if (pontuacaoA != pontuacaoB) {
                return pontuacaoB.compareTo(
                  pontuacaoA,
                );
              }

              return b.length.compareTo(
                a.length,
              );
            },
          );

          nome = candidatos.first;
        }
      }

      // ==========================================================
      // TERCEIRA TENTATIVA
      //
      // Junta linhas que parecem continuação do título.
      // ==========================================================

      if (nome.isNotEmpty) {
        final List<String> tituloCompleto =
            _montarTituloCompleto(
          linhas,
          nome,
          indicePreco,
          linhaEhLixo,
        );

        if (tituloCompleto.isNotEmpty) {
          nome = tituloCompleto.join(' ');
        }
      }

      // ==========================================================
      // LIMPEZA FINAL
      // ==========================================================

      nome = _limparNomeProduto(nome);

      if (!mounted) return;

      setState(() {
        _textoLido = texto;
        _nomeProduto = nome;
        _preco = _normalizarPreco(preco);
      });
    } catch (e) {
      if (!mounted) return;

      _mostrarMensagem(
        'Erro ao reconhecer o texto do print.\n\n$e',
      );
    } finally {
      await reconhecedor.close();
    }
  }

  // ============================================================
  // PONTUAÇÃO DE LINHA
  // ============================================================

  int _pontuarLinhaProduto(String linha) {
    final String t =
        linha.toLowerCase();

    int pontos = 0;

    if (t.length >= 10) {
      pontos += 2;
    }

    if (t.length >= 20) {
      pontos += 2;
    }

    if (t.length >= 40) {
      pontos += 2;
    }

    // Marcas / modelos normalmente aparecem em títulos.
    final List<String> indicadores = [
      'projetor',
      'ventilador',
      'mesa',
      'notebook',
      'celular',
      'fone',
      'headset',
      'cadeira',
      'smart',
      'tv',
      'monitor',
      'câmera',
      'camera',
      'controle',
      'teclado',
      'mouse',
      'air fryer',
      'liquidificador',
      'aspirador',
      'máquina',
      'maquina',
    ];

    for (final String palavra in indicadores) {
      if (t.contains(palavra)) {
        pontos += 5;
      }
    }

    return pontos;
  }

  // ============================================================
  // MONTAR TÍTULO COMPLETO
  // ============================================================

  List<String> _montarTituloCompleto(
    List<String> linhas,
    String nomeAtual,
    int indicePreco,
    bool Function(String) linhaEhLixo,
  ) {
    final List<String> resultado = [];

    int inicio = -1;

    // Primeiro tentamos localizar exatamente a linha
    // que foi escolhida.
    for (int i = 0; i < linhas.length; i++) {
      if (linhas[i].trim() == nomeAtual.trim()) {
        inicio = i;
        break;
      }
    }

    // Se encontrou a linha, tenta juntar as próximas.
    if (inicio >= 0) {
      for (
        int i = inicio;
        i < linhas.length && i < inicio + 4;
        i++
      ) {
        final String linha =
            linhas[i].trim();

        if (linhaEhLixo(linha)) {
          break;
        }

        if (regexPrecoGlobal.hasMatch(linha)) {
          break;
        }

        if (linha.length > 220) {
          break;
        }

        resultado.add(linha);
      }
    }

    // Se não conseguiu montar, mantém o nome original.
    if (resultado.isEmpty) {
      return [nomeAtual];
    }

    return resultado;
  }

  // Regex auxiliar para montagem do título.
  RegExp get regexPrecoGlobal {
    return RegExp(
      r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
      caseSensitive: false,
    );
  }

  // ============================================================
  // LIMPAR NOME DO PRODUTO
  // ============================================================

  String _limparNomeProduto(String nome) {
    String resultado =
        nome.trim();

    // Remove comissão em qualquer formato.
    final List<RegExp> remover = [
      RegExp(
        r'comiss[aã]o\s*extra',
        caseSensitive: false,
      ),
      RegExp(
        r'comiss[aã]oextra',
        caseSensitive: false,
      ),
      RegExp(
        r'comiss[aã]o',
        caseSensitive: false,
      ),
      RegExp(
        r'\b\d+[,.]?\d*\s*%',
        caseSensitive: false,
      ),
    ];

    for (final RegExp regex in remover) {
      resultado =
          resultado.replaceAll(
        regex,
        ' ',
      );
    }

    // Remove "No.11", "No. 11" etc.
    resultado =
        resultado.replaceAll(
      RegExp(
        r'\bno\.?\s*\d+\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove alguns textos que jamais devem
    // fazer parte do nome.
    final List<RegExp> frases = [
      RegExp(
        r'mais vendidos.*',
        caseSensitive: false,
      ),
      RegExp(
        r'aprenda com outros criadores.*',
        caseSensitive: false,
      ),
      RegExp(
        r'afiliados promoveram.*',
        caseSensitive: false,
      ),
      RegExp(
        r'compartilhe para ganhar.*',
        caseSensitive: false,
      ),
    ];

    for (final RegExp regex in frases) {
      resultado =
          resultado.replaceAll(
        regex,
        ' ',
      );
    }

    // Remove preço caso tenha entrado no nome.
    resultado =
        resultado.replaceAll(
      regexPrecoGlobal,
      ' ',
    );

    // Limpa pontuação solta no começo.
    resultado =
        resultado.replaceFirst(
      RegExp(r'^[\s\-:|,]+'),
      '',
    );

    // Junta espaços duplicados.
    resultado =
        resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return resultado.trim();
  }

  // ============================================================
  // NORMALIZAR PREÇO
  // ============================================================

  String _normalizarPreco(String preco) {
    String resultado =
        preco.trim();

    if (resultado.isEmpty) {
      return '';
    }

    if (!resultado
        .toLowerCase()
        .contains('r\$')) {
      resultado = 'R\$ $resultado';
    }

    return resultado;
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
  // ============================================================

  Future<File?> _criarImagemFinal() async {
    if (_imagemRecortada == null) {
      return null;
    }

    try {
      final Uint8List bytes =
          await _imagemRecortada!.readAsBytes();

      final img.Image? foto =
          img.decodeImage(bytes);

      if (foto == null) {
        return _imagemRecortada;
      }

      final int largura =
          foto.width;

      final int alturaFoto =
          foto.height;

      final int alturaFaixa =
          (largura * 0.20).round();

      final int alturaTotal =
          alturaFoto + alturaFaixa;

      final img.Image resultado =
          img.Image(
        width: largura,
        height: alturaTotal,
      );

      img.fill(
        resultado,
        color: img.ColorRgb8(
          255,
          255,
          255,
        ),
      );

      img.compositeImage(
        resultado,
        foto,
        dstX: 0,
        dstY: 0,
      );

      img.fillRect(
        resultado,
        x1: 0,
        y1: alturaFoto,
        x2: largura - 1,
        y2: alturaTotal - 1,
        color: img.ColorRgb8(
          5,
          102,
          72,
        ),
      );

      final List<int> png =
          img.encodePng(resultado);

      final String caminho =
          '${Directory.systemTemp.path}/divulgacao_final_${DateTime.now().millisecondsSinceEpoch}.png';

      final File arquivo =
          File(caminho);

      await arquivo.writeAsBytes(png);

      return arquivo;
    } catch (e) {
      return _imagemRecortada;
    }
  }

  // ============================================================
  // COMPARTILHAR
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

    if (_imagemRecortada == null) {
      _mostrarMensagem(
        'Escolha o print do produto primeiro.',
      );
      return;
    }

    try {
      setState(() {
        _carregando = true;
      });

      final File? imagemFinal =
          await _criarImagemFinal();

      if (!mounted) return;

      setState(() {
        _carregando = false;
      });

      if (imagemFinal == null) {
        _mostrarMensagem(
          'Não foi possível preparar a imagem.',
        );
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
            XFile(
              imagemFinal.path,
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
      });

      _mostrarMensagem(
        'Não foi possível compartilhar.\n\n$e',
      );
    }
  }

  // ============================================================
  // COMPARTILHAR SOMENTE TEXTO
  // ============================================================

  Future<void> _compartilharTexto() async {
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
      _imagemOriginal = null;
      _imagemRecortada = null;

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
  // CARD DA IMAGEM
  // ============================================================

  Widget _cardImagemRecortada() {
    if (_imagemRecortada == null) {
      return const SizedBox.shrink();
    }

    return Card(
      clipBehavior:
          Clip.antiAlias,
      elevation: 3,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(14),
            color:
                const Color(0xFFFFF0EB),
            child: const Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color:
                      Colors.deepOrange,
                ),
                SizedBox(width: 10),
                Text(
                  'FOTO RECORTADA',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            width: double.infinity,
            child: Image.file(
              _imagemRecortada!,
              fit: BoxFit.contain,
            ),
          ),
        ],
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
              // ESCOLHER FOTO
              // ==================================================

              ElevatedButton.icon(
                onPressed:
                    _carregando
                        ? null
                        : _escolherPrint,
                icon: const Icon(
                  Icons.photo_library,
                ),
                label: const Text(
                  'ESCOLHER FOTO / PRINT DO PRODUTO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                style:
                    ElevatedButton
                        .styleFrom(
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
                          'Preparando o produto...',
                          textAlign:
                              TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              // ==================================================
              // FOTO
              // ==================================================

              if (!_carregando)
                _cardImagemRecortada(),

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
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      18,
                    ),
                    child: Column(
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
                                FontWeight
                                    .bold,
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
                            fontSize: 19,
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
                                Colors.grey,
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
                            fontSize: 22,
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
                          const EdgeInsets
                              .all(16),
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
              // COMPARTILHAR FOTO
              // ==================================================

              if (_nomeProduto
                      .isNotEmpty ||
                  _preco.isNotEmpty)
                ElevatedButton.icon(
                  onPressed:
                      _carregando
                          ? null
                          : _compartilhar,
                  icon:
                      const Icon(
                    Icons.image,
                  ),
                  label:
                      const Text(
                    'COMPARTILHAR FOTO + DIVULGAÇÃO',
                    style:
                        TextStyle(
                      fontSize: 16,
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
              // COMPARTILHAR TEXTO
              // ==================================================

              if (_nomeProduto
                      .isNotEmpty ||
                  _preco.isNotEmpty)
                OutlinedButton.icon(
                  onPressed:
                      _compartilharTexto,
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

              if (_imagemOriginal !=
                  null)
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
                'A imagem é apenas recortada. '
                'O aplicativo não remove o fundo do produto, '
                'evitando deformações e falhas no recorte.',
                textAlign:
                    TextAlign.center,
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
