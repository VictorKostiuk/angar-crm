# Only initialize missing accounts. Reseeding must never reset a real password.
[
  { email_address: "angarvelokafe@gmail.com", name: "Женя", payroll_percent: 0, password_env: "SEED_OWNER_PASSWORD" },
  { email_address: "vityok.kostiuk@gmail.com", name: "Viktor", payroll_percent: 35, password_env: "SEED_VIKTOR_PASSWORD" }
].each do |attributes|
  User.find_or_create_by!(email_address: attributes[:email_address]) do |user|
    user.name = attributes[:name]
    user.role = :owner
    user.payroll_percent = attributes[:payroll_percent]
    user.active = true
    user.password = ENV.fetch(attributes[:password_env]) do
      raise "Set #{attributes[:password_env]} to initialize this production owner" if Rails.env.production?
      "password123"
    end
  end
end

service_category_names = %w[ Загальне\ ТО Трансмісія Гальма Колеса Рульове\ управління Підвіска Палки\ і\ аксесуари ]
part_category_names = [
  "Ланцюги", "Касети / тріскалки", "Троси / рубашки", "Гальмівні колодки",
  "Камери", "Покришки", "Мастила / герметики", "Підшипники", "Каретки", "Інше"
]

service_categories = service_category_names.each_with_index.to_h do |name, i|
  [ name, Category.find_or_create_by!(kind: :service, name: name) { |c| c.position = i } ]
end

part_categories = part_category_names.each_with_index.to_h do |name, i|
  [ name, Category.find_or_create_by!(kind: :part, name: name) { |c| c.position = i } ]
end

services = [
  [ "Повне ТО велосипеда", "Загальне ТО", 1800 ],
  [ "Базове ТО велосипеда", "Загальне ТО", 900 ],
  [ "Заміна ланцюга", "Трансмісія", 250 ],
  [ "Налаштування заднього перемикача", "Трансмісія", 300 ],
  [ "Прокачка гальма", "Гальма", 450 ],
  [ "Заміна гальмівних колодок", "Гальма", 250 ],
  [ "Центрування колеса", "Колеса", 350 ],
  [ "Перебірка втулки", "Колеса", 500 ],
  [ "Налаштування рульової", "Рульове управління", 250 ],
  [ "Перебірка вилки", "Підвіска", 1200 ],
  [ "Встановлення багажника", "Палки і аксесуари", 300 ],
  [ "Заміна обмотки керма", "Палки і аксесуари", 250 ]
]

services.each_with_index do |(name, category_name, price), i|
  Service.find_or_create_by!(name: name) do |service|
    service.assign_attributes(category: service_categories.fetch(category_name), base_price: price, position: i)
  end
end

parts = [
  [ "Ланцюг КМС X10", "Ланцюги", 950 ],
  [ "Трос перемикача Shimano", "Троси / рубашки", 120 ],
  [ "Трос гальма Shimano", "Троси / рубашки", 120 ],
  [ "Камера 700x35/43", "Камери", 180 ],
  [ "Колодки Shimano B01S", "Гальмівні колодки", 350 ],
  [ "Покришка Schwalbe Marathon 700x32", "Покришки", 1450 ],
  [ "Герметик для безкамерних шин", "Мастила / герметики", 350 ],
  [ "Каретка Shimano BB-RS500", "Каретки", 650 ]
]

parts.each_with_index do |(name, category_name, price), i|
  Part.find_or_create_by!(name: name) do |part|
    part.assign_attributes(category: part_categories.fetch(category_name), base_price: price, position: i)
  end
end

puts "Catalogs ready: #{Service.count} services, #{Part.count} parts, #{Category.count} categories"
