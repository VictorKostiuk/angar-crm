class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Відновлення пароля", to: user.email_address
  end
end
