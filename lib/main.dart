import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;

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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
      });

      _mostrarMensagem(
        'Erro ao abrir a imagem.\n\n$e',
      );
    }
  }

  // ============================================================
  // LIMPAR TUDO
  // ============================================================

  void _limparTudo() {
    setState(() {
      _imagemOriginal = null;
      _imagemRecortada = null;
      _nomeProduto = '';
      _preco = '';
      _textoLido = '';
      _linkController.clear();
      _carregando = false;
    });

    _mostrarMensagem(
      'Tudo limpo.',
    );
  }

  // ============================================================
  // LIMPAR LINHA OCR
  // ============================================================

  String _limparLinha(String texto) {
    String t = texto.trim();

    // ----------------------------------------------------------
    // REMOVE COMISSÃO EXTRA
    // ----------------------------------------------------------

    t = t.replaceAll(
      RegExp(
        r'comiss[aã]o\s*ex\s*tra',
        caseSensitive: false,
      ),
      ' ',
    );

    t = t.replaceAll(
      RegExp(
        r'comiss[aã]oextra',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE PORCENTAGENS
    // ----------------------------------------------------------

    t = t.replaceAll(
      RegExp(
        r'\b\d{1,3}(?:[.,]\d+)?\s*%',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE LINKS
    // ----------------------------------------------------------

    t = t.replaceAll(
      RegExp(
        r'https?://\S+',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE RETICÊNCIAS
    // ----------------------------------------------------------

    t = t.replaceAll(
      RegExp(r'\.{2,}|…+'),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE ALGUNS TEXTOS DE INTERFACE
    // ----------------------------------------------------------

    final palavrasRemover = [
      'aprenda com outros criadores',
      'compartilhe para ganhar',
      'compartilhar',
      'compartilhe',
      'favorito',
      'chat',
      'afiliados promoveram',
      'afiliados',
      'afiliado',
      'promoveram',
      'vendido',
      'vendidos',
      'avaliações',
      'avaliacoes',
      'cupom',
      'frete grátis',
      'frete gratis',
      'comprar agora',
      'adicionar ao carrinho',
      'parcelado',
      'entrega',
      'confira aqui',
      'aproveite a oferta',
    ];

    for (final palavra in palavrasRemover) {
      t = t.replaceAll(
        RegExp(
          RegExp.escape(palavra),
          caseSensitive: false,
        ),
        ' ',
      );
    }

    // ----------------------------------------------------------
    // ESPAÇOS
    // ----------------------------------------------------------

    t = t.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return t.trim();
  }

  // ============================================================
  // VERIFICAR TEXTO DE INTERFACE
  // ============================================================

  bool _ehInterface(String texto) {
    final t = texto.toLowerCase().trim();

    if (t.isEmpty) {
      return true;
    }

    final termos = [
      'comissão extra',
      'comissao extra',
      'comissãoextra',
      'comissaoextra',
      'afiliados',
      'afiliado',
      'promoveram',
      'aprenda com outros criadores',
      'compartilhe para ganhar',
      'compartilhar',
      'compartilhe',
      'favorito',
      'chat',
      'vendido',
      'vendidos',
      'avaliações',
      'avaliacoes',
      'cupom',
      'frete grátis',
      'frete gratis',
      'comprar agora',
      'adicionar ao carrinho',
      'entrega',
      'parcelado',
      'visitar',
      'mais vendidos',
    ];

    for (final termo in termos) {
      if (t.contains(termo)) {
        return true;
      }
    }

    // ----------------------------------------------------------
    // PORCENTAGEM
    // ----------------------------------------------------------

    if (RegExp(
      r'\d+(?:[.,]\d+)?\s*%',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }

    // ----------------------------------------------------------
    // HORÁRIO DO CELULAR
    // ----------------------------------------------------------

    if (RegExp(
      r'^\d{1,2}:\d{2}$',
    ).hasMatch(t)) {
      return true;
    }

    // ----------------------------------------------------------
    // SOMENTE NÚMEROS
    // ----------------------------------------------------------

    if (RegExp(
      r'^[\d\s.,/%\-]+$',
    ).hasMatch(t)) {
      return true;
    }

    return false;
  }

  // ============================================================
  // NORMALIZAR PREÇO
  // ============================================================

  String _normalizarPreco(String preco) {
    String p = preco.trim();

    if (p.isEmpty) {
      return '';
    }

    p = p.replaceAll(
      RegExp(r'\s+'),
      '',
    );

    if (!p.toLowerCase().startsWith('r\$')) {
      p = 'R\$$p';
    }

    return p;
  }

  // ============================================================
  // EXTRAIR PREÇO DE UMA LINHA
  // ============================================================

  String _extrairPreco(String texto) {
    final RegExp regexPreco = RegExp(
      r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*,\d{2}',
      caseSensitive: false,
    );

    final Match? match =
        regexPreco.firstMatch(texto);

    if (match == null) {
      return '';
    }

    final String valor =
        match.group(0) ?? '';

    if (valor.isEmpty) {
      return '';
    }

    return _normalizarPreco(valor);
  }

  // ============================================================
  // REMOVER PREÇO DA LINHA
  //
  // EXEMPLO:
  //
  // R$397,00 Projetor VEVSHAO A12
  //
  // vira:
  //
  // Projetor VEVSHAO A12
  // ============================================================

  String _removerPrecoDaLinha(String texto) {
    String resultado = texto;

    final RegExp regexPreco = RegExp(
      r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*,\d{2}',
      caseSensitive: false,
    );

    resultado = resultado.replaceAll(
      regexPreco,
      ' ',
    );

    resultado = resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return resultado.trim();
  }

  // ============================================================
  // AJUSTAR NOME
  // ============================================================

  String _ajustarNomeProduto(String nome) {
    String n = _limparLinha(nome);

    // ----------------------------------------------------------
    // REMOVE QUALQUER PREÇO QUE TENHA SOBRADO
    // ----------------------------------------------------------

    n = _removerPrecoDaLinha(n);

    // ----------------------------------------------------------
    // REMOVE COMISSÃO EXTRA NOVAMENTE
    // ----------------------------------------------------------

    n = n.replaceAll(
      RegExp(
        r'comiss[aã]o\s*ex\s*tra',
        caseSensitive: false,
      ),
      ' ',
    );

    n = n.replaceAll(
      RegExp(
        r'\b\d{1,3}(?:[.,]\d+)?\s*%',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE RETICÊNCIAS
    // ----------------------------------------------------------

    n = n.replaceAll(
      RegExp(r'\.{2,}|…+'),
      ' ',
    );

    // ----------------------------------------------------------
    // ESPAÇOS
    // ----------------------------------------------------------

    n = n.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    n = n.trim();

    // ----------------------------------------------------------
    // LIMITE
    // ----------------------------------------------------------

    if (n.length > 170) {
      n = n.substring(0, 170);

      final int pos =
          n.lastIndexOf(' ');

      if (pos > 20) {
        n = n.substring(0, pos);
      }
    }

    return n.trim();
  }

  // ============================================================
  // RECORTAR FOTO
  //
  // NÃO REMOVE O FUNDO.
  // Apenas recorta a área da foto do produto.
  // ============================================================

  Future<File?> _recortarAreaDoProduto(
    String caminho,
  ) async {
    try {
      final File arquivo =
          File(caminho);

      final Uint8List bytes =
          await arquivo.readAsBytes();

      final img.Image? original =
          img.decodeImage(bytes);

      if (original == null) {
        return null;
      }

      final int largura =
          original.width;

      final int altura =
          original.height;

      final int topo =
          (altura * 0.045).round();

      final int fundo =
          (altura * 0.435).round();

      final int margem =
          (largura * 0.025).round();

      final int larguraRecorte =
          largura - margem * 2;

      final int alturaRecorte =
          fundo - topo;

      if (larguraRecorte <= 0 ||
          alturaRecorte <= 0) {
        return null;
      }

      final img.Image recorte =
          img.copyCrop(
        original,
        x: margem,
        y: topo,
        width: larguraRecorte,
        height: alturaRecorte,
      );

      final String novoCaminho =
          '${arquivo.parent.path}/produto_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final File resultado =
          File(novoCaminho);

      await resultado.writeAsBytes(
        Uint8List.fromList(
          img.encodeJpg(
            recorte,
            quality: 95,
          ),
        ),
      );

      return resultado;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // OCR PRINCIPAL
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
          InputImage.fromFilePath(
        caminho,
      );

      final RecognizedText resultado =
          await reconhecedor.processImage(
        imagem,
      );

      final List<_LinhaOCR> linhas =
          [];

      // --------------------------------------------------------
      // PEGAR TODAS AS LINHAS
      // --------------------------------------------------------

      for (final bloco
          in resultado.blocks) {
        for (final linha
            in bloco.lines) {
          final String texto =
              linha.text.trim();

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

      // --------------------------------------------------------
      // ORDENAR DE CIMA PARA BAIXO
      // --------------------------------------------------------

      linhas.sort((a, b) {
        final int y =
            a.caixa.top.compareTo(
          b.caixa.top,
        );

        if (y != 0) {
          return y;
        }

        return a.caixa.left.compareTo(
          b.caixa.left,
        );
      });

      // ========================================================
      // ENCONTRAR PREÇO
      // ========================================================

      String preco = '';

      int indicePreco = -1;

      for (int i = 0;
          i < linhas.length;
          i++) {
        final String valor =
            _extrairPreco(
          linhas[i].texto,
        );

        if (valor.isNotEmpty) {
          preco = valor;
          indicePreco = i;
          break;
        }
      }

      // ========================================================
      // MONTAR NOME DO PRODUTO
      // ========================================================

      final List<String> partesNome =
          [];

      // --------------------------------------------------------
      // CASO 1:
      //
      // PREÇO E NOME ESTÃO NA MESMA LINHA
      //
      // Exemplo:
      //
      // R$397,00 Projetor VEVSHAO A12
      //
      // ou:
      //
      // Projetor VEVSHAO A12 R$397,00
      // --------------------------------------------------------

      if (indicePreco >= 0) {
        final String linhaComPreco =
            linhas[indicePreco].texto;

        final String restante =
            _removerPrecoDaLinha(
          linhaComPreco,
        );

        final String restanteLimpo =
            _limparLinha(restante);

        if (restanteLimpo.isNotEmpty &&
            !_ehInterface(restanteLimpo) &&
            restanteLimpo.length >= 4) {
          partesNome.add(
            restanteLimpo,
          );
        }
      }

      // ========================================================
      // CASO 2:
      //
      // O TÍTULO CONTINUA NAS LINHAS ABAIXO DO PREÇO
      // ========================================================

      if (indicePreco >= 0) {
        for (int i = indicePreco + 1;
            i < linhas.length;
            i++) {
          final String original =
              linhas[i].texto.trim();

          if (original.isEmpty) {
            continue;
          }

          // ----------------------------------------------------
          // PARAR AO ENCONTRAR ELEMENTOS DE INTERFACE
          // ----------------------------------------------------

          final String originalMinusculo =
              original.toLowerCase();

          if (originalMinusculo.contains(
                'afiliados',
              ) ||
              originalMinusculo.contains(
                'vendido',
              ) ||
              originalMinusculo.contains(
                'avaliacoes',
              ) ||
              originalMinusculo.contains(
                'avaliações',
              ) ||
              originalMinusculo.contains(
                'aprenda com outros criadores',
              ) ||
              originalMinusculo.contains(
                'compartilhe para ganhar',
              )) {
            break;
          }

          // ----------------------------------------------------
          // NÃO PEGAR PORCENTAGEM
          // ----------------------------------------------------

          if (RegExp(
            r'\d+(?:[.,]\d+)?\s*%',
          ).hasMatch(original)) {
            continue;
          }

          // ----------------------------------------------------
          // LIMPAR
          // ----------------------------------------------------

          String linha =
              _limparLinha(original);

          linha =
              _removerPrecoDaLinha(
            linha,
          );

          linha =
              _limparLinha(linha);

          if (linha.isEmpty) {
            continue;
          }

          // ----------------------------------------------------
          // NÃO PEGAR INTERFACE
          // ----------------------------------------------------

          if (_ehInterface(linha)) {
            break;
          }

          // ----------------------------------------------------
          // NÃO PEGAR SOMENTE NÚMEROS
          // ----------------------------------------------------

          if (RegExp(
            r'^[\d\s.,/%\-]+$',
          ).hasMatch(linha)) {
            continue;
          }

          // ----------------------------------------------------
          // TAMANHO
          // ----------------------------------------------------

          if (linha.length < 4) {
            continue;
          }

          if (linha.length > 120) {
            continue;
          }

          partesNome.add(linha);

          // Títulos normalmente possuem poucas linhas.
          if (partesNome.length >= 4) {
            break;
          }
        }
      }

      // ========================================================
      // CASO 3:
      //
      // SE NÃO ENCONTROU PREÇO, TENTAR ENCONTRAR O TÍTULO
      // SEM CONFUNDIR O PREÇO COM O NOME.
      // ========================================================

      if (partesNome.isEmpty) {
        for (final linhaOCR in linhas) {
          String linha =
              _limparLinha(
            linhaOCR.texto,
          );

          if (linha.isEmpty) {
            continue;
          }

          // ----------------------------------------------------
          // Se houver preço nessa linha, retirar primeiro.
          // ----------------------------------------------------

          linha =
              _removerPrecoDaLinha(
            linha,
          );

          linha =
              _limparLinha(linha);

          if (linha.isEmpty) {
            continue;
          }

          if (_ehInterface(linha)) {
            continue;
          }

          if (RegExp(
            r'\d+(?:[.,]\d+)?\s*%',
          ).hasMatch(linha)) {
            continue;
          }

          if (RegExp(
            r'^[\d\s.,/%\-]+$',
          ).hasMatch(linha)) {
            continue;
          }

          if (linha.length < 8) {
            continue;
          }

          if (linha.length > 120) {
            continue;
          }

          partesNome.add(linha);

          if (partesNome.length >= 2) {
            break;
          }
        }
      }

      // ========================================================
      // MONTAR NOME
      // ========================================================

      String nome =
          partesNome.join(' ');

      nome =
          _ajustarNomeProduto(nome);

      // ========================================================
      // PROTEÇÃO FINAL:
      // NUNCA DEIXAR R$ DENTRO DO NOME
      // ========================================================

      nome =
          _removerPrecoDaLinha(nome);

      nome =
          _limparLinha(nome);

      // --------------------------------------------------------
      // REMOVER PORCENTAGEM
      // --------------------------------------------------------

      nome = nome.replaceAll(
        RegExp(
          r'\b\d{1,3}(?:[.,]\d+)?\s*%',
        ),
        ' ',
      );

      // --------------------------------------------------------
      // REMOVER COMISSÃO EXTRA
      // --------------------------------------------------------

      nome = nome.replaceAll(
        RegExp(
          r'comiss[aã]o\s*ex\s*tra',
          caseSensitive: false,
        ),
        ' ',
      );

      // --------------------------------------------------------
      // ESPAÇOS
      // --------------------------------------------------------

      nome = nome.replaceAll(
        RegExp(r'\s+'),
        ' ',
      ).trim();

      // ========================================================
      // RECORTAR FOTO
      // ========================================================

      final File? foto =
          await _recortarAreaDoProduto(
        caminho,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _textoLido = resultado.text;
        _nomeProduto = nome;
        _preco = preco;
        _imagemRecortada = foto;
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
        'Erro ao reconhecer o print.\n\n$e',
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

    return '''
🛍️ $nome

🔥 OFERTA NA SHOPEE 🔥

💰 $preco

👇 Confira aqui:
${_obterLink()}

🛒 Aproveite a oferta!
'''.trim();
  }

  // ============================================================
  // COMPARTILHAR FOTO
  // ============================================================

  Future<void> _compartilharFoto() async {
    if (_obterLink().isEmpty) {
      _mostrarMensagem(
        'Digite o link de afiliado.',
      );
      return;
    }

    if (_imagemOriginal == null) {
      _mostrarMensagem(
        'Escolha um print.',
      );
      return;
    }

    final File arquivo =
        _imagemRecortada ??
            _imagemOriginal!;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              _gerarTextoDivulgacao(),
          files: [
            XFile(
              arquivo.path,
            ),
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
    if (_obterLink().isEmpty) {
      _mostrarMensagem(
        'Digite o link de afiliado.',
      );
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              _gerarTextoDivulgacao(),
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

  void _mostrarMensagem(
    String texto,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(texto),
        duration:
            const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================
  // CAMPO LINK
  // ============================================================

  Widget _campoLink() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: TextField(
        controller:
            _linkController,
        keyboardType:
            TextInputType.url,
        decoration:
            InputDecoration(
          hintText:
              'Link do produto / link de afiliado',
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
    );
  }

  // ============================================================
  // FOTO
  // ============================================================

  Widget _foto() {
    if (_imagemRecortada == null) {
      return const SizedBox();
    }

    return Container(
      margin:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        color:
            Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.15),
            blurRadius: 5,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        child: Image.file(
          _imagemRecortada!,
          width:
              double.infinity,
          fit:
              BoxFit.contain,
        ),
      ),
    );
  }

  // ============================================================
  // INFORMAÇÕES
  // ============================================================

  Widget _informacoes() {
    return Container(
      margin:
          const EdgeInsets.all(16),
      padding:
          const EdgeInsets.all(28),
      width:
          double.infinity,
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFFF1EC),
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.15),
            blurRadius: 5,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'INFORMAÇÕES ENCONTRADAS',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 26,
          ),

          Text(
            'NOME DO PRODUTO',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            _nomeProduto.isEmpty
                ? 'Produto não identificado'
                : _nomeProduto,
            style:
                const TextStyle(
              fontSize: 27,
              fontWeight:
                  FontWeight.bold,
              height: 1.3,
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          Text(
            'PREÇO',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            _preco.isEmpty
                ? 'Não identificado'
                : _preco,
            style:
                const TextStyle(
              fontSize: 30,
              fontWeight:
                  FontWeight.bold,
              color:
                  Colors.deepOrange,
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
  Widget build(
    BuildContext context,
  ) {
    final bool temImagem =
        _imagemOriginal != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Colors.deepOrange,
        foregroundColor:
            Colors.white,
        centerTitle: true,
        title:
            const Text(
          'Divulgador Shopee',
          style: TextStyle(
            fontSize: 30,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      body:
          SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(
              height: 30,
            ),

            _campoLink(),

            const SizedBox(
              height: 24,
            ),

            Padding(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 16,
              ),
              child: SizedBox(
                width:
                    double.infinity,
                height: 120,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _carregando
                          ? null
                          : _escolherPrint,
                  icon:
                      const Icon(
                    Icons
                        .image_outlined,
                    size: 32,
                  ),
                  label:
                      const Text(
                    'ESCOLHER FOTO / PRINT DO PRODUTO',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            if (_carregando)
              const Padding(
                padding:
                    EdgeInsets.all(
                  35,
                ),
                child:
                    CircularProgressIndicator(),
              ),

            if (!_carregando &&
                temImagem)
              _foto(),

            if (!_carregando &&
                temImagem)
              _informacoes(),

            if (!_carregando &&
                temImagem)
              Padding(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 16,
                ),
                child: SizedBox(
                  width:
                      double.infinity,
                  height: 55,
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        _limparTudo,
                    icon:
                        const Icon(
                      Icons
                          .delete_outline,
                    ),
                    label:
                        const Text(
                      'LIMPAR TUDO',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            if (!_carregando &&
                temImagem)
              Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  16,
                  18,
                  16,
                  30,
                ),
                child:
                    Column(
                  children: [
                    SizedBox(
                      width:
                          double.infinity,
                      height: 58,
                      child:
                          ElevatedButton.icon(
                        onPressed:
                            _compartilharFoto,
                        icon:
                            const Icon(
                          Icons.image,
                        ),
                        label:
                            const Text(
                          'COMPARTILHAR FOTO + DIVULGAÇÃO',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
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
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      height: 52,
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            _compartilharTexto,
                        icon:
                            const Icon(
                          Icons.share,
                        ),
                        label:
                            const Text(
                          'COMPARTILHAR SOMENTE TEXTO',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (!temImagem &&
                !_carregando)
              const Padding(
                padding:
                    EdgeInsets.fromLTRB(
                  35,
                  60,
                  35,
                  20,
                ),
                child:
                    Text(
                  'O aplicativo identifica automaticamente o preço e o título do produto, recorta somente a área da foto e prepara a divulgação.',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    fontSize: 18,
                    height: 1.5,
                    color:
                        Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
