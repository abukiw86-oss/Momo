<?php 
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");

require_once 'db.php'; 

if (!isset($_GET['user_id']) || !isset($_GET['email'])) {
    http_response_code(400);
    echo json_encode(["error" => "Missing required parameters: user_id and email."]);
    exit;
}

$user_id = trim($_GET['user_id']);
$email   = trim($_GET['email']);
 
try { 
    $stmt = $pdo->prepare("SELECT image_path FROM user_profiles WHERE user_id = :user_id AND email = :email LIMIT 1");
    $stmt->execute([
        ':user_id' => $user_id,
        ':email'   => $email
    ]);
    
    $user = $stmt->fetch();

    if ($user) { 
        http_response_code(200);
        echo json_encode([
            "success" => true,
            "image_path" => $user['image_path']
        ]);
    } else { 
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "error" => "No user found with those credentials."
        ]);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["error" => "An error occurred while processing your request."]);
}