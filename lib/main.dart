import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const DivulgadorShopeeApp());
}

class DivulgadorShopeeApp extends StatelessWidget {
  const DivulgadorShopeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Divulgador Shopee',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
        ),
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
  final ImagePicker picker = ImagePicker();

  final TextEditingController nomeController =
      TextEditingController();

  final TextEditingController precoController =
      TextEditingController();

  final TextEditingController linkController =
      TextEditingController();

  File? imagemSelecionada;

  bool lendoImagem = false;

  String textoDetectado = '';

  @override
  void dispose() {
    nomeController.dispose();
    precoController.dispose();
    linkController.dispose();
    super.dispose();
  }

  Future<void> selecionarPrint() async {
    try {
      final XFile? imagem = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (imagem == null) {
        return;
      }

      setState(() {
        imagemSelecionada = File(imagem.path);
        lendoImagem = true;
        textoDetectado = '';
      });

      await reconhecerTexto(imagem.path);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        lendoImagem = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível selecionar a imagem: $e',
          ),
        ),
      );
    }
  }

  Future<void> reconhecerTexto(String caminho) async {
    final TextRecognizer reconhecedor =
        TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final InputImage imagem =
          InputImage.fromFilePath(caminho);

      final RecognizedText resultado =
          await reconhecedor.processImage(imagem);

      final String texto = resultado.text;

      setState(() {
        textoDetectado = texto;
      });

      preencherAutomaticamente(texto);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não consegui ler o texto do print: $e',
          ),
        ),
      );
    } finally {
      await reconhecedor.close();

      if (mounted) {
        setState(() {
          lendoImagem = false;
        });
      }
    }
  }

  void preencherAutomaticamente(String texto) {
    final linhas = texto
        .split('\n')
        .map((linha) => linha.trim())
        .where((linha) => linha.isNotEmpty)
        .toList();

    String precoEncontrado = '';
    String nomeEncontrado = '';

    // Procura valores como:
    // R$ 39,90
    // R$39,90
    // 39,90
    // 39.90
    final RegExp regexPreco = RegExp(
      r'(?:R\$\s*)?\d{1,6}(?:[.,]\d{2})',
      caseSensitive: false,
    );

    for (final linha in linhas) {
      final match = regexPreco.firstMatch(linha);

      if (match != null) {
        String valor = match.group(0) ?? '';

        valor = valor
            .replaceAll('R\$', '')
            .trim();

        precoEncontrado = valor;

        break;
      }
    }

    // Tenta encontrar um nome de produto.
    //
    // Ignora linhas que claramente parecem:
    // preço, frete, parcelas, avaliações,
    // links e textos muito curtos.
    final List<String> candidatos = [];

    for (final linha in linhas) {
      final String minusculo =
          linha.toLowerCase();

      if (linha.length < 8) {
        continue;
      }

      if (linha.length > 160) {
        continue;
      }

      if (minusculo.contains('r\$')) {
        continue;
      }

      if (minusculo.contains('frete')) {
        continue;
      }

      if (minusculo.contains('parcela')) {
        continue;
      }

      if (minusculo.contains('avalia')) {
        continue;
      }

      if (minusculo.contains('vendido')) {
        continue;
      }

      if (minusculo.contains('comprado')) {
        continue;
      }

      if (minusculo.contains('http')) {
        continue;
      }

      candidatos.add(linha);
    }

    if (candidatos.isNotEmpty) {
      candidatos.sort(
        (a, b) => b.length.compareTo(a.length),
      );

      nomeEncontrado = candidatos.first;
    }

    if (nomeEncontrado.isEmpty) {
      nomeEncontrado = 'Produto Shopee';
    }

    if (mounted) {
      setState(() {
        nomeController.text = nomeEncontrado;

        if (precoEncontrado.isNotEmpty) {
          precoController.text = precoEncontrado;
        }
      });
    }
  }

  String montarDivulgacao() {
    final String nome =
        nomeController.text.trim().isEmpty
            ? 'Oferta Shopee'
            : nomeController.text.trim();

    final String preco =
        precoController.text.trim().isEmpty
            ? 'Confira o preço'
            : precoController.text.trim();

    final String link =
        linkController.text.trim();

    return '''
🔥 OFERTA SHOPEE 🔥

🛍️ $nome

💰 R\$ $preco

🛒 COMPRE AQUI:
$link

⚡ Aproveite a oferta!
''';
  }

  Future<void> copiarDivulgacao() async {
    final String link =
        linkController.text.trim();

    if (link.isEmpty) {
      mostrarMensagem(
        'Cole primeiro o seu link de afiliado.',
      );
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: montarDivulgacao(),
      ),
    );

    mostrarMensagem(
      'Divulgação copiada!',
    );
  }

  Future<void> compartilharDivulgacao() async {
    final String link =
        linkController.text.trim();

    if (link.isEmpty) {
      mostrarMensagem(
        'Cole primeiro o seu link de afiliado.',
      );
      return;
    }

    final String texto =
        montarDivulgacao();

    await SharePlus.instance.share(
      ShareParams(
        text: texto,
        title: 'Oferta Shopee',
      ),
    );
  }

  void limparTudo() {
    setState(() {
      imagemSelecionada = null;
      textoDetectado = '';
      nomeController.clear();
      precoController.clear();
      linkController.clear();
    });
  }

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: limparTudo,
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.white,
            ),
            tooltip: 'Limpar',
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [

              const Text(
                '1. Escolha o print do produto',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed:
                    lendoImagem
                        ? null
                        : selecionarPrint,
                icon: const Icon(
                  Icons.photo_library,
                  size: 28,
                ),
                label: Text(
                  lendoImagem
                      ? 'LENDO O PRINT...'
                      : 'SELECIONAR PRINT',
                ),
                style:
                    OutlinedButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(58),
                ),
              ),

              const SizedBox(height: 18),

              if (imagemSelecionada != null)
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(15),
                  child: Image.file(
                    imagemSelecionada!,
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color:
                        Colors.grey.shade200,
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  child: const Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 70,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'O print aparecerá aqui',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 25),

              const Text(
                '2. Confira as informações',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: nomeController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Nome do produto',
                  hintText:
                      'O nome será reconhecido pelo print',
                  prefixIcon:
                      const Icon(Icons.shopping_bag),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: precoController,
                keyboardType:
                    TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Preço',
                  hintText: 'Ex.: 39,90',
                  prefixIcon:
                      const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                '3. Cole seu link de afiliado',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: linkController,
                keyboardType:
                    TextInputType.url,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText:
                      'Seu link de afiliado Shopee',
                  hintText:
                      'Cole aqui o seu link de afiliado',
                  prefixIcon:
                      const Icon(Icons.link),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                '4. Divulgação',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding:
                    const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color:
                      Colors.orange.shade50,
                  borderRadius:
                      BorderRadius.circular(15),
                  border: Border.all(
                    color:
                        Colors.orange.shade200,
                  ),
                ),
                child: Text(
                  montarDivulgacao(),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              ElevatedButton.icon(
                onPressed:
                    copiarDivulgacao,
                icon: const Icon(
                  Icons.copy,
                ),
                label: const Text(
                  'COPIAR DIVULGAÇÃO',
                ),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.deepOrange,
                  foregroundColor:
                      Colors.white,
                  minimumSize:
                      const Size.fromHeight(56),
                ),
              ),

              const SizedBox(height: 10),

              ElevatedButton.icon(
                onPressed:
                    compartilharDivulgacao,
                icon: const Icon(
                  Icons.share,
                ),
                label: const Text(
                  'COMPARTILHAR',
                ),
                style:
                    ElevatedButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(56),
                ),
              ),

              const SizedBox(height: 25),

              if (textoDetectado.isNotEmpty)
                ExpansionTile(
                  title: const Text(
                    'Texto reconhecido no print',
                  ),
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.all(12),
                      child: Text(
                        textoDetectado,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
