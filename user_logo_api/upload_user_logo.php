<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
require_once 'db.php';

if (!isset($_POST['user_id']) || !isset($_POST['email'])) {
    http_response_code(400);
    echo json_encode(["error" => "Missing required fields: user_id and email."]);
    exit;
}

$user_id = trim($_POST['user_id']);
$email   = trim($_POST['email']);
 
$check_stmt = $pdo->prepare("SELECT id FROM user_image WHERE user_id = :user_id LIMIT 1");
$check_stmt->execute([':user_id' => $user_id]);

if ($check_stmt->fetch()) {
    http_response_code(409); 
    echo json_encode(["error" => "An account with this user_id already exists."]);
    exit;
}
 
$image_path = 'assets/logo.png';  

if (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
    $file = $_FILES['image'];
 
    $allowed_types = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (!in_array($file['type'], $allowed_types)) {
        http_response_code(400);
        echo json_encode(["error" => "Invalid file type. Only JPG, PNG, GIF, and WEBP are allowed."]);
        exit;
    }
 
    $upload_dir = 'assets/';
    if (!is_dir($upload_dir)) {
        mkdir($upload_dir, 0755, true);
    }
 
    $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $new_filename = "user_" . $user_id . "_" . time() . "." . $extension;
    $target_file_path = $upload_dir . $new_filename;
 
    if (move_uploaded_file($file['tmp_name'], $target_file_path)) {
        $image_path = $target_file_path; 
    } else {
        http_response_code(500);
        echo json_encode(["error" => "Failed to save uploaded file."]);
        exit;
    }
}
 
try {
    $insert_stmt = $pdo->prepare("INSERT INTO user_image (user_id, email, image_path) VALUES (:user_id, :email, :image_path)");
    $insert_stmt->execute([
        ':user_id'    => $user_id,
        ':email'      => $email,
        ':image_path' => $image_path
    ]);

    http_response_code(201); 
    echo json_encode([
        "success" => true,
        "message" => "Account created successfully.",
        "data" => [
            "user_id" => $user_id,
            "email" => $email,
            "image_path" => $image_path
        ]
    ]);

} catch (Exception $e) { 
    if ($image_path !== 'assets/logo.png' && file_exists($image_path)) {
        unlink($image_path);
    }
    http_response_code(500);
    echo json_encode(["error" => "Database insertion failed: " . $e->getMessage()]);
}