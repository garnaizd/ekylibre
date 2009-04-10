# == Schema Information
# Schema version: 20090410102120
#
# Table name: invoices
#
#  id                :integer       not null, primary key
#  client_id         :integer       not null
#  nature            :string(1)     not null
#  number            :string(64)    not null
#  amount            :decimal(16, 2 default(0.0), not null
#  amount_with_taxes :decimal(16, 2 default(0.0), not null
#  payment_delay_id  :integer       not null
#  payment_on        :date          not null
#  paid              :boolean       not null
#  lost              :boolean       not null
#  has_downpayment   :boolean       not null
#  downpayment_price :decimal(16, 2 default(0.0), not null
#  contact_id        :integer       not null
#  company_id        :integer       not null
#  created_at        :datetime      not null
#  updated_at        :datetime      not null
#  created_by        :integer       
#  updated_by        :integer       
#  lock_version      :integer       default(0), not null
#  sale_order_id     :integer       
#

class Invoice < ActiveRecord::Base

  belongs_to :client, :class_name=>Entity.to_s
  belongs_to :company
  belongs_to :contact
  belongs_to :payment_delay, :class_name=>Delay.to_s
  belongs_to :sale_order
  has_many :deliveries
  has_many :lines, :class_name=>InvoiceLine.to_s

  def before_validation
    if self.number.blank?
      last = self.client.invoices.find(:first, :order=>"number desc")
      self.number = if last
                      last.number.succ!
                    else
                      '00000001'
                    end
    end
  end
  
  def self.generate(company_id, records, options={})
    puts "mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm"+records.class.to_s
    invoice = Invoice.new(:company_id=>company_id, :nature=>"S")
    case records.class.to_s
      
    when "Array"
      for record in records
        invoice.amount += record.amount
        invoice.amount_with_taxes += record.amount_with_taxes
      end
      invoice.sale_order_id = records[0].order_id
      invoice.payment_delay_id = records[0].order.payment_delay_id
      invoice.client_id = records[0].order.client_id
      invoice.contact_id = records[0].order.invoice_contact_id
      invoice.payment_on = Date.today
      invoice.save!
      for record in records
        record.update_attributes!(:invoice_id=>invoice.id)
        for lines in record.lines
          invoice_line = InvoiceLine.create!(:company_id=>lines.company_id,:amount=>lines.amount,
                                             :amount_with_taxes=>lines.amount_with_taxes,:invoice_id=>invoice.id,
                                             :order_line_id=>lines.order_line_id,:quantity=>lines.order_line.quantity)
          invoice_line.save!
        end
      end

      
    when "Delivery"
      invoice.amount = records.amount
      invoice.amount_with_taxes = records.amount_with_taxes
      invoice.payment_delay_id = records.order.payment_delay_id
      invoice.client_id = records.order.client_id
      invoice.payment_on = Date.today
      invoice.sale_order_id = records.id
      invoice.contact_id = records.order.invoice_contact_id
      invoice.save!
      records.update_attributes!(:invoice_id=>invoice.id)
      for lines in records.lines
        line = InvoiceLine.create!(:company_id=>lines.company_id,:amount=>lines.amount,
                                    :amount_with_taxes=>lines.amount_with_taxes,:invoice_id=>invoice.id,
                                    :order_line_id=>lines.order_line_id,:quantity=>lines.order_line.quantity)
        line.save
      end
      
    when "SaleOrder"
      invoice.amount = records.amount
      invoice.amount_with_taxes = records.amount_with_taxes
      invoice.payment_delay_id = records.payment_delay_id
      invoice.client_id = records.client_id
      invoice.payment_on = Date.today
      invoice.contact_id = records.invoice_contact_id
      invoice.sale_order_id = records.id
      invoice.save!
      puts invoice.inspect
      records.update_attributes!(:invoiced=>true)
      for lines in records.lines
        line = InvoiceLine.create!(:company_id=>lines.company_id,:amount=>lines.amount,
                                   :amount_with_taxes=>lines.amount_with_taxes,:invoice_id=>invoice.id,
                                   :order_line_id=>lines.id,:quantity=>lines.quantity)
        line.save
      end
    end
    
  end
  


end
