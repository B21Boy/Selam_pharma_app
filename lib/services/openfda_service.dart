import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenFdaService {
  Future<Map<String, dynamic>?> fetchDrugInfo(String drugName) async {
    final url = Uri.parse(
      'https://api.fda.gov/drug/label.json?search=openfda.brand_name:"$drugName"&limit=1',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['results'] != null && data['results'].isNotEmpty) {
        final result = data['results'][0];

        return {
          "brandName": result['openfda']?['brand_name']?[0],
          "genericName": result['openfda']?['generic_name']?[0],
          "activeIngredient": result['openfda']?['active_ingredient']?[0],
          "indications": result['indications_and_usage']?[0],
          "warnings": result['warnings']?[0],
          "dosage": result['dosage_and_administration']?[0],
          "sideEffects": result['adverse_reactions']?[0],
        };
      }
    }

    return null;
  }
}
