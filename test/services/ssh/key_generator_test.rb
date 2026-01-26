require "test_helper"

class Ssh::KeyGeneratorTest < ActiveSupport::TestCase
  test "generates ed25519 key" do
    key = Ssh::KeyGenerator.generate(key_type: "ed25519", comment: "test@vault")

    assert_not_nil key
    assert_equal "ed25519", key.key_type
    assert_equal 256, key.key_bits
    assert_not_nil key.private_key
    assert_not_nil key.public_key
    assert_not_nil key.fingerprint

    assert key.private_key.include?("OPENSSH PRIVATE KEY")
    assert key.public_key.start_with?("ssh-ed25519")
    assert key.fingerprint.start_with?("SHA256:")
  end

  test "generates rsa-2048 key" do
    key = Ssh::KeyGenerator.generate(key_type: "rsa-2048", comment: "test@vault")

    assert_not_nil key
    assert_equal "rsa-2048", key.key_type
    assert_equal 2048, key.key_bits
    assert key.private_key.include?("RSA PRIVATE KEY") || key.private_key.include?("PRIVATE KEY")
    assert key.public_key.start_with?("ssh-rsa")
    assert key.fingerprint.start_with?("SHA256:")
  end

  test "generates rsa-4096 key" do
    key = Ssh::KeyGenerator.generate(key_type: "rsa-4096", comment: "test@vault")

    assert_not_nil key
    assert_equal "rsa-4096", key.key_type
    assert_equal 4096, key.key_bits
    assert key.public_key.start_with?("ssh-rsa")
  end

  test "raises error for invalid key type" do
    assert_raises ArgumentError do
      Ssh::KeyGenerator.generate(key_type: "invalid")
    end
  end

  test "valid_type? returns correct values" do
    assert Ssh::KeyGenerator.valid_type?("ed25519")
    assert Ssh::KeyGenerator.valid_type?("rsa-2048")
    assert Ssh::KeyGenerator.valid_type?("rsa-4096")
    assert_not Ssh::KeyGenerator.valid_type?("dsa")
    assert_not Ssh::KeyGenerator.valid_type?("invalid")
  end

  test "supported_types returns all types" do
    types = Ssh::KeyGenerator.supported_types
    assert_includes types, "ed25519"
    assert_includes types, "rsa-2048"
    assert_includes types, "rsa-4096"
  end

  test "fingerprint calculates SHA256 hash" do
    # Use a known public key for testing
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGVqF1n7FqLv1Ktest test@example"
    fp = Ssh::KeyGenerator.fingerprint(public_key)

    assert fp.start_with?("SHA256:")
    assert fp.length > 10
  end

  test "includes comment in public key" do
    key = Ssh::KeyGenerator.generate(key_type: "ed25519", comment: "my-comment")
    assert key.public_key.include?("my-comment")
  end
end
