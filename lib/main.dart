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
  final TextEditingController _linkController = TextEditingController();

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
  // LIMPAR TUDO
  // ============================================================

  void _limparTudo() {
    setState(() {
      _imagemOriginal = null;
      _imagemRecortada = null;
      _nomeProduto = '';
      _preco = '';
      _textoLido = '';
      _carregando = false;
      _linkController.clear();
    });

    _mostrarMensagem(
      'Tudo limpo. Você pode adicionar outro print.',
    );
  }

  // ============================================================
  // LIMPAR LINHA OCR
  // ============================================================

  String _limparLinha(String texto) {
    String resultado = texto.trim();

    // ----------------------------------------------------------
    // REMOVE COMISSÃO EXTRA
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'comiss[aã]o\s*ex\s*tra',
        caseSensitive: false,
      ),
      ' ',
    );

    resultado = resultado.replaceAll(
      RegExp(
        r'comiss[aã]oextra',
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

    // ----------------------------------------------------------
    // REMOVE PORCENTAGENS
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'\b\d{1,3}(?:[.,]\d+)?\s*%',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE No.11 / Nº11 ETC.
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'\b(?:no|nº|n°)\.?\s*\d+\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE PALAVRAS DE COMISSÃO
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'\b(?:comissão|comissao|extra)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // ----------------------------------------------------------
    // REMOVE TEXTOS DA INTERFACE
    // ----------------------------------------------------------

    final palavrasRemover = [
      'mais vendidos',
      'aprenda com outros criadores',
      'compartilhe para ganhar',
      'compartilhar',
      'compartilhe',
      'favorito',
      'chat',
      'afiliados promoveram',
      'afiliados',
      'afiliado',
      'vendido',
      'vendidos',
      'avaliações',
      'avaliacoes',
      'oferta',
      'promoção',
      'promocao',
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
    // REMOVE RETICÊNCIAS
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(r'\.{2,}'),
      ' ',
    );

    resultado = resultado.replaceAll(
      RegExp(r'…+'),
      ' ',
    );

    // ----------------------------------------------------------
    // ESPAÇOS
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    resultado = resultado.trim();

    // ----------------------------------------------------------
    // PONTUAÇÃO NAS EXTREMIDADES
    // ----------------------------------------------------------

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
  // VERIFICAR TEXTO IGNORADO
  // ============================================================

  bool _ehTextoIgnorado(String texto) {
    final t = texto.toLowerCase().trim();

    if (t.isEmpty) {
      return true;
    }

    // ----------------------------------------------------------
    // PREÇO
    // ----------------------------------------------------------

    if (RegExp(
      r'(?:r\$|\d{1,3}(?:[.\s]\d{3})*,\d{2})',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }

    // ----------------------------------------------------------
    // PORCENTAGEM
    // ----------------------------------------------------------

    if (RegExp(
      r'\d+(?:[.,]\d+)?\s*%',
    ).hasMatch(t)) {
      return true;
    }

    // ----------------------------------------------------------
    // TEXTOS QUE NÃO PERTENCEM AO NOME
    // ----------------------------------------------------------

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
      'confira aqui',
      'aproveite a oferta',
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

    // ----------------------------------------------------------
    // LINHAS MUITO CURTAS
    // ----------------------------------------------------------

    if (t.length < 3) {
      return true;
    }

    return false;
  }

  // ============================================================
  // VERIFICAR SE É UMA LINHA DE INTERFACE
  // ============================================================

  bool _ehInterface(String texto) {
    final t = texto.toLowerCase().trim();

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
      'favorito',
      'chat',
      'mais vendidos',
      'vendido',
      'vendidos',
      'avaliações',
      'avaliacoes',
      'oferta',
      'promoção',
      'promocao',
      'cupom',
      'frete grátis',
      'frete gratis',
      'adicionar ao carrinho',
      'comprar agora',
      'parcelado',
      'entrega',
    ];

    for (final termo in termos) {
      if (t.contains(termo)) {
        return true;
      }
    }

    if (RegExp(
      r'\d+(?:[.,]\d+)?\s*%',
    ).hasMatch(t)) {
      return true;
    }

    return false;
  }

  // ============================================================
  // AJUSTAR NOME
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
    // REMOVE RETICÊNCIAS NO FINAL
    // ----------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(r'(\.{2,}|…+)\s*$'),
      '',
    );

    // ----------------------------------------------------------
    // REMOVE REPETIÇÃO DA ÚLTIMA PALAVRA
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

    // ----------------------------------------------------------
    // LIMPEZA FINAL
    // ----------------------------------------------------------

    resultado = resultado
        .replaceAll(
          RegExp(r'(\.{2,}|…+)\s*$'),
          '',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();

    return resultado;
  }

  // ============================================================
  // RECORTAR SOMENTE A FOTO
  //
  // IMPORTANTE:
  // NÃO REMOVE O FUNDO.
  //
  // Apenas corta a área superior onde está a foto do produto.
  // ============================================================

  Future<File?> _recortarAreaDoProduto(
    String caminho,
  ) async {
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

      // --------------------------------------------------------
      // TOPO
      //
      // Retira somente a barra de status do celular.
      // --------------------------------------------------------

      int topo =
          (altura * 0.035).round();

      // --------------------------------------------------------
      // FINAL DA FOTO
      //
      // A área principal da foto da Shopee termina normalmente
      // antes da região do preço/título.
      //
      // Usamos 44% para evitar que o preço apareça.
      // --------------------------------------------------------

      int fundo =
          (altura * 0.44).round();

      // --------------------------------------------------------
      // SEGURANÇA
      // --------------------------------------------------------

      if (topo < 0) {
        topo = 0;
      }

      if (fundo > altura) {
        fundo = altura;
      }

      if (fundo <= topo) {
        fundo =
            (altura * 0.44).round();
      }

      // --------------------------------------------------------
      // MARGEM LATERAL
      //
      // Retira somente uma pequena borda.
      // O fundo da imagem continua intacto.
      // --------------------------------------------------------

      final int margemX =
          (largura * 0.025).round();

      int esquerda = margemX;
      int direita = largura - margemX;

      if (esquerda < 0) {
        esquerda = 0;
      }

      if (direita > largura) {
        direita = largura;
      }

      final int novaLargura =
          direita - esquerda;

      final int novaAltura =
          fundo - topo;

      if (novaLargura <= 0 ||
          novaAltura <= 0) {
        return null;
      }

      final img.Image recortada =
          img.copyCrop(
        original,
        x: esquerda,
        y: topo,
        width: novaLargura,
        height: novaAltura,
      );

      final Uint8List resultadoBytes =
          Uint8List.fromList(
        img.encodeJpg(
          recortada,
          quality: 95,
        ),
      );

      final String novoCaminho =
          '${arquivo.parent.path}/produto_recortado_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final File novoArquivo =
          File(novoCaminho);

      await novoArquivo.writeAsBytes(
        resultadoBytes,
      );

      return novoArquivo;
    } catch (e) {
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
          InputImage.fromFilePath(caminho);

      final RecognizedText resultado =
          await reconhecedor.processImage(
        imagem,
      );

      final String textoCompleto =
          resultado.text.trim();

      final List<_LinhaOCR> linhas = [];

      // --------------------------------------------------------
      // PEGAR TODAS AS LINHAS + POSIÇÃO
      // --------------------------------------------------------

      for (final bloco
          in resultado.blocks) {
        for (final linha
            in bloco.lines) {
          final texto =
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
        final diferencaY =
            a.caixa.top.compareTo(
          b.caixa.top,
        );

        if (diferencaY != 0) {
          return diferencaY;
        }

        return a.caixa.left.compareTo(
          b.caixa.left,
        );
      });

      // --------------------------------------------------------
      // PREÇO
      // --------------------------------------------------------

      final RegExp regexPreco =
          RegExp(
        r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
        caseSensitive: false,
      );

      String preco = '';

      int indiceLinhaPreco = -1;

      for (int i = 0;
          i < linhas.length;
          i++) {
        final texto =
            linhas[i].texto;

        final match =
            regexPreco.firstMatch(
          texto,
        );

        if (match != null) {
          final valor =
              match.group(0) ?? '';

          if (valor.isNotEmpty) {
            preco = valor;
            indiceLinhaPreco = i;
            break;
          }
        }
      }

      // ========================================================
      // NOME DO PRODUTO
      //
      // CORREÇÃO PRINCIPAL:
      //
      // O título da Shopee fica DEPOIS DA FOTO e ANTES DO PREÇO.
      //
      // O código antigo procurava depois do preço e acabava
      // capturando informações que não pertenciam ao título.
      // ========================================================

      final List<String> partesNome = [];

      // --------------------------------------------------------
      // Primeiro encontramos uma região aproximada onde termina
      // a foto.
      //
      // Essa posição é baseada no mesmo recorte usado na imagem.
      // --------------------------------------------------------

      double limiteDepoisDaFoto =
          0;

      if (linhas.isNotEmpty) {
        final maiorBottom =
            linhas
                .map(
                  (linha) =>
                      linha.caixa.bottom,
                )
                .reduce(
                  (a, b) =>
                      a > b ? a : b,
                );

        limiteDepoisDaFoto =
            maiorBottom * 0.44;
      }

      // --------------------------------------------------------
      // Procuramos o título:
      //
      // 1. abaixo da área da foto;
      // 2. antes do preço;
      // 3. ignorando interface;
      // 4. podendo ter várias linhas.
      // --------------------------------------------------------

      for (int i = 0;
          i < linhas.length;
          i++) {
        final linhaOCR =
            linhas[i];

        final String original =
            linhaOCR.texto.trim();

        // Não pegar texto muito acima da região do título.
        if (linhaOCR.caixa.top <
            limiteDepoisDaFoto) {
          continue;
        }

        // Se já encontramos preço,
        // o título precisa estar ANTES dele.
        if (indiceLinhaPreco >= 0 &&
            i >= indiceLinhaPreco) {
          break;
        }

        if (_ehInterface(original)) {
          continue;
        }

        String linha =
            _limparLinha(original);

        if (linha.isEmpty) {
          continue;
        }

        if (_ehTextoIgnorado(linha)) {
          continue;
        }

        if (linha.length < 3) {
          continue;
        }

        if (linha.length > 120) {
          continue;
        }

        // ------------------------------------------------------
        // Evita colocar números soltos ou elementos de interface.
        // ------------------------------------------------------

        if (RegExp(
          r'^[\d\s.,/%\-]+$',
        ).hasMatch(linha)) {
          continue;
        }

        partesNome.add(linha);

        // ------------------------------------------------------
        // Títulos da Shopee podem ter várias linhas.
        // Permite até 6 linhas.
        // ------------------------------------------------------

        if (partesNome.length >= 6) {
          break;
        }
      }

      // ========================================================
      // SEGUNDO MÉTODO DE SEGURANÇA
      //
      // Se não encontrou o título pelo posicionamento,
      // procura linhas próximas ao preço, mas ANTES dele.
      // ========================================================

      if (partesNome.isEmpty &&
          indiceLinhaPreco >= 0) {
        for (int i = indiceLinhaPreco - 1;
            i >= 0;
            i--) {
          final original =
              linhas[i].texto.trim();

          if (_ehInterface(original)) {
            continue;
          }

          String linha =
              _limparLinha(original);

          if (linha.isEmpty) {
            continue;
          }

          if (_ehTextoIgnorado(linha)) {
            continue;
          }

          if (linha.length < 3 ||
              linha.length > 120) {
            continue;
          }

          if (RegExp(
            r'^[\d\s.,/%\-]+$',
          ).hasMatch(linha)) {
            continue;
          }

          partesNome.insert(
            0,
            linha,
          );

          if (partesNome.length >= 6) {
            break;
          }
        }
      }

      // ========================================================
      // FALLBACK
      // ========================================================

      if (partesNome.isEmpty) {
        for (final linhaOCR
            in linhas) {
          String linha =
              _limparLinha(
            linhaOCR.texto,
          );

          if (linha.isEmpty) {
            continue;
          }

          if (_ehTextoIgnorado(linha)) {
            continue;
          }

          if (_ehInterface(linha)) {
            continue;
          }

          if (linha.length < 5 ||
              linha.length > 120) {
            continue;
          }

          if (RegExp(
            r'^[\d\s.,/%\-]+$',
          ).hasMatch(linha)) {
            continue;
          }

          partesNome.add(linha);

          if (partesNome.length >= 4) {
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

      // Última limpeza.
      nome =
          _limparLinha(nome);

      // ========================================================
      // REMOVE QUALQUER RESTO DE RETICÊNCIAS
      // ========================================================

      nome = nome.replaceAll(
        RegExp(r'(\.{2,}|…+)'),
        ' ',
      );

      nome = nome.replaceAll(
        RegExp(r'\s+'),
        ' ',
      ).trim();

      // ========================================================
      // LIMITADOR
      // ========================================================

      if (nome.length > 180) {
        nome =
            nome.substring(0, 180).trim();

        final ultimoEspaco =
            nome.lastIndexOf(' ');

        if (ultimoEspaco > 20) {
          nome =
              nome.substring(
            0,
            ultimoEspaco,
          ).trim();
        }
      }

      // ========================================================
      // RECORTAR FOTO
      // ========================================================

      final File? fotoRecortada =
          await _recortarAreaDoProduto(
        caminho,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _textoLido = textoCompleto;
        _nomeProduto = nome;
        _preco = preco;
        _imagemRecortada =
            fotoRecortada;
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
  // COMPARTILHAR FOTO + TEXTO
  // ============================================================

  Future<void> _compartilharFoto() async {
    final String link =
        _obterLink();

    if (link.isEmpty) {
      _mostrarMensagem(
        'Digite o seu link de afiliado antes de compartilhar.',
      );
      return;
    }

    if (_imagemOriginal == null) {
      _mostrarMensagem(
        'Escolha o print do produto primeiro.',
      );
      return;
    }

    final String texto =
        _gerarTextoDivulgacao();

    try {
      final File arquivoParaCompartilhar =
          _imagemRecortada ??
              _imagemOriginal!;

      await SharePlus.instance.share(
        ShareParams(
          text: texto,
          subject:
              'Oferta Shopee - $_nomeProduto',
          files: [
            XFile(
              arquivoParaCompartilhar.path,
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

  void _mostrarMensagem(
    String mensagem,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(mensagem),
        duration:
            const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================
  // CAMPO DE LINK
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
          labelText:
              'Link de afiliado Shopee',
          hintText:
              'Cole seu link aqui',
          prefixIcon:
              const Icon(Icons.link),
          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              14,
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
  // CARD DA FOTO
  // ============================================================

  Widget _cardFoto() {
    if (_imagemRecortada == null &&
        _imagemOriginal == null) {
      return const SizedBox.shrink();
    }

    final File imagem =
        _imagemRecortada ??
            _imagemOriginal!;

    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        0,
      ),
      padding:
          const EdgeInsets.all(8),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.18),
            blurRadius: 5,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        child: Image.file(
          imagem,
          width:
              double.infinity,
          fit: BoxFit.contain,
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
      margin:
          const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        0,
      ),
      padding:
          const EdgeInsets.fromLTRB(
        32,
        28,
        32,
        28,
      ),
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
                .withOpacity(0.18),
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
                  Colors.grey.shade500,
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          Text(
            'NOME DO PRODUTO',
            style: TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.bold,
              color:
                  Colors.grey.shade500,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            _nomeProduto.isEmpty
                ? 'Produto não identificado'
                : _nomeProduto,
            style:
                const TextStyle(
              fontSize: 28,
              height: 1.35,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          Text(
            'PREÇO',
            style: TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.bold,
              color:
                  Colors.grey.shade500,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            _preco.isEmpty
                ? 'Preço não identificado'
                : _preco,
            style:
                const TextStyle(
              fontSize: 28,
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
  // BOTÃO LIMPAR
  // ============================================================

  Widget _botaoLimpar() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        0,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child:
            OutlinedButton.icon(
          onPressed:
              _carregando
                  ? null
                  : _limparTudo,
          icon:
              const Icon(
            Icons.delete_outline,
          ),
          label:
              const Text(
            'LIMPAR TUDO',
            style: TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          style:
              OutlinedButton
                  .styleFrom(
            foregroundColor:
                Colors.deepOrange,
            side:
                const BorderSide(
              color:
                  Colors.deepOrange,
              width: 1.5,
            ),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTÕES COMPARTILHAR
  // ============================================================

  Widget _botoesCompartilhar() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        30,
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 58,
            child:
                ElevatedButton.icon(
              onPressed:
                  _carregando
                      ? null
                      : _compartilharFoto,
              icon:
                  const Icon(
                Icons.image,
              ),
              label:
                  const Text(
                'COMPARTILHAR FOTO + DIVULGAÇÃO',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    Colors.deepOrange,
                foregroundColor:
                    Colors.white,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          SizedBox(
            width: double.infinity,
            height: 52,
            child:
                OutlinedButton.icon(
              onPressed:
                  _carregando
                      ? null
                      : _compartilharTexto,
              icon:
                  const Icon(
                Icons.share,
              ),
              label:
                  const Text(
                'COMPARTILHAR SOMENTE TEXTO',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              style:
                  OutlinedButton
                      .styleFrom(
                foregroundColor:
                    Colors.deepOrange,
                side:
                    const BorderSide(
                  color:
                      Colors.deepOrange,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
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
  Widget build(
    BuildContext context,
  ) {
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

      body: SafeArea(
        child:
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
                  width: double.infinity,
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
                      size: 30,
                    ),
                    label:
                        const Text(
                      'ESCOLHER FOTO / PRINT DO PRODUTO',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          const Color(
                        0xFFFFEEE8,
                      ),
                      foregroundColor:
                          const Color(
                        0xFF8D4A39,
                      ),
                      elevation: 0,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (_carregando)
                const Padding(
                  padding:
                      EdgeInsets.all(
                    30,
                  ),
                  child:
                      CircularProgressIndicator(),
                ),

              if (!_carregando &&
                  (_imagemOriginal !=
                          null ||
                      _imagemRecortada !=
                          null))
                _cardFoto(),

              if (!_carregando &&
                  (_imagemOriginal !=
                          null ||
                      _imagemRecortada !=
                          null))
                _cardInformacoes(),

              if (!_carregando &&
                  (_imagemOriginal !=
                          null ||
                      _imagemRecortada !=
                          null))
                _botaoLimpar(),

              if (!_carregando &&
                  (_imagemOriginal !=
                          null ||
                      _imagemRecortada !=
                          null))
                _botoesCompartilhar(),

              if (_imagemOriginal ==
                      null &&
                  !_carregando)
                const Padding(
                  padding:
                      EdgeInsets.fromLTRB(
                    40,
                    50,
                    40,
                    20,
                  ),
                  child:
                      Text(
                    'O aplicativo separa somente a área da foto do produto, '
                    'mantém o fundo original, remove informações como '
                    'COMISSÃO EXTRA do nome e prepara a divulgação.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      height: 1.5,
                      color:
                          Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
