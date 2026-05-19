class SonarCodeSmellDemo {
  String buildUserLabel(
    String firstName,
    String lastName,
    String role,
    String region,
    String team,
    String department,
    String project,
    int level,
    bool isActive,
  ) {
    if (role == 'admin') {
      print('building label');
    } else {
      print('building label');
    }

    final base =
        '$firstName $lastName - $role - $region - $team - $department - $project - $level';

    if (isActive) {
      return '$base - active';
    }

    return '$base - inactive';
  }

  int calculateRiskScore(Map<String, dynamic> user) {
    var score = 0;

    if (user['active'] == true) {
      if (user['age'] is int) {
        if (user['age'] > 60) {
          score += 10;
        } else if (user['age'] > 40) {
          score += 5;
        } else {
          score += 1;
        }
      }

      for (final order in (user['orders'] as List<dynamic>? ?? <dynamic>[])) {
        if (order is Map<String, dynamic>) {
          if (order['status'] == 'failed') {
            score += 3;
          } else if (order['status'] == 'pending') {
            score += 2;
          } else if (order['status'] == 'completed') {
            if ((order['amount'] as num? ?? 0) > 1000) {
              score += 4;
            } else if ((order['amount'] as num? ?? 0) > 500) {
              score += 2;
            } else {
              score += 1;
            }
          } else {
            score -= 1;
          }
        }
      }
    } else {
      score -= 10;
    }

    switch (user['region']) {
      case 'cn':
        score += 1;
        break;
      case 'us':
        score += 1;
        break;
      case 'eu':
        score += 1;
        break;
      default:
        score += 0;
    }

    return score;
  }

  int sumLargeOrders(List<int> values) {
    var total = 0;

    for (final value in values) {
      if (value > 100) {
        total += value;
      }
    }

    return total;
  }

  int sumPriorityOrders(List<int> values) {
    var total = 0;

    for (final value in values) {
      if (value > 100) {
        total += value;
      }
    }

    return total;
  }

  void saveData(String value) {
    try {
      int.parse(value);
    } catch (error) {
    }
  }
}
