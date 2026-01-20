provider "aws" {
  region = "us-east-1"
}

# 1. Tạo một con EC2 cấu hình cao (t3.xlarge ~ $120/tháng)
resource "aws_instance" "app_server" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS (us-east-1)
  instance_type = "t3.xlarge"

  tags = {
    Name        = "Kiro-Cost-Test-Server"
    Environment = "Staging"
  }
}

# 2. Gắn thêm ổ cứng dòng IOPS cao (io2) - Loại này rất đắt tiền
resource "aws_ebs_volume" "data_drive" {
  availability_zone = aws_instance.app_server.availability_zone
  size              = 100   # 100 GB
  type              = "io2" # Provisioned IOPS SSD (Đắt hơn gp3 nhiều)
  iops              = 3000  # 3000 IOPS
  
  tags = {
    Name = "Expensive-Data-Volume"
  }
}

# 3 Gắn ổ cứng vào Server
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.data_drive.id
  instance_id = aws_instance.app_server.id
}